import 'package:flutter/material.dart';
import 'package:savebite_mobile/request_board/data/dummy_requests.dart';
import 'package:savebite_mobile/request_board/models/food_request.dart';
import 'package:savebite_mobile/request_board/models/paginated_response.dart';
import 'package:savebite_mobile/request_board/models/request_offer.dart';
import 'package:savebite_mobile/request_board/services/request_board_service.dart';
import 'package:savebite_mobile/request_board/widgets/offer_card.dart';
import 'package:savebite_mobile/request_board/widgets/request_card.dart';

/// Exception penanda bahwa backend menutup penawaran baru (`409 offers_closed`)
/// saat pengguna mencoba menawarkan bantuan.
class OffersClosedException implements Exception {
  final String message;

  const OffersClosedException([
    this.message = 'Penawaran untuk permintaan ini sudah ditutup.',
  ]);

  @override
  String toString() => message;
}

/// Hasil navigasi kembali dari [RequestDetailPage] agar halaman daftar dapat
/// langsung menyinkronkan perubahan atau penghapusan.
class RequestDetailResult {
  final FoodRequest? updatedRequest;
  final int? deletedRequestId;

  const RequestDetailResult({
    this.updatedRequest,
    this.deletedRequestId,
  });
}

/// Halaman detail sebuah [FoodRequest] beserta manajemen penawaran (`OfferCard`)
/// dan aksi berbasis kepemilikan serta status aktif permintaan.
class RequestDetailPage extends StatefulWidget {
  final FoodRequest request;
  final int? currentUserId;
  final List<RequestOffer>? initialOffers;
  final bool initialHasNextOffersPage;

  /// Callback opsional untuk integrasi REST API di Tahap 4.
  /// Jika tidak disediakan, halaman beroperasi dengan state lokal/dummy.
  final Future<FoodRequest?> Function(int requestId)? onRefreshDetail;
  final Future<PaginatedResponse<RequestOffer>?> Function(
    int requestId,
    int page,
  )? onLoadOffers;
  final Future<FoodRequest?> Function(int requestId)? onSubmitOffer;
  final Future<FoodRequest?> Function(int requestId, int offerId)? onSelectOffer;
  final Future<FoodRequest?> Function(int requestId)? onFulfillRequest;
  final Future<bool> Function(int requestId)? onDeleteRequest;
  final VoidCallback? onNavigateToLogin;
  final RequestBoardService? service;

  const RequestDetailPage({
    super.key,
    required this.request,
    this.currentUserId = dummyCurrentUserId,
    this.initialOffers,
    this.initialHasNextOffersPage = false,
    this.onRefreshDetail,
    this.onLoadOffers,
    this.onSubmitOffer,
    this.onSelectOffer,
    this.onFulfillRequest,
    this.onDeleteRequest,
    this.onNavigateToLogin,
    this.service,
  });

  @override
  State<RequestDetailPage> createState() => _RequestDetailPageState();
}

class _RequestDetailPageState extends State<RequestDetailPage> {
  late FoodRequest _request;
  List<RequestOffer> _offers = [];
  int _offersPage = 1;
  bool _hasNextOffersPage = false;
  bool _isLoadingDetail = false;
  bool _isLoadingOffers = false;
  bool _isActionInProgress = false;
  bool _offersClosedLocally = false;
  bool _hasChanges = false;

  /// Token generasi untuk mengabaikan respons asinkron lama saat sesi pengguna
  /// berubah (logout / ganti akun) atau `request.id` berganti.
  int _requestGeneration = 0;
  int? _effectiveCurrentUserId;

  bool get _isGuest => _effectiveCurrentUserId == null;
  bool get _isOwner =>
      _effectiveCurrentUserId != null &&
      _effectiveCurrentUserId == _request.owner.id;

  @override
  void initState() {
    super.initState();
    _request = widget.request;
    _effectiveCurrentUserId =
        widget.currentUserId ?? widget.service?.sessionClient.currentUserId;
    widget.service?.sessionClient.addListener(_handleSessionClientChanged);

    if (widget.service != null &&
        widget.onRefreshDetail == null &&
        widget.initialOffers == null) {
      Future.microtask(() {
        if (mounted) {
          _refreshDetail();
        }
      });
    } else {
      _initOffersForCurrentSession();
    }
  }

  @override
  void dispose() {
    widget.service?.sessionClient.removeListener(_handleSessionClientChanged);
    super.dispose();
  }

  void _handleSessionClientChanged() {
    if (!mounted || widget.service == null) return;
    final nextUserId = widget.service!.sessionClient.currentUserId;
    if (nextUserId == _effectiveCurrentUserId) return;
    _applySessionOrRequestChange(
      requestChanged: false,
      sessionChanged: true,
      nextUserId: nextUserId,
    );
  }

  @override
  void didUpdateWidget(covariant RequestDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      oldWidget.service?.sessionClient
          .removeListener(_handleSessionClientChanged);
      widget.service?.sessionClient.addListener(_handleSessionClientChanged);
    }

    final requestChanged = widget.request.id != oldWidget.request.id;
    final nextUserId =
        widget.currentUserId ?? widget.service?.sessionClient.currentUserId;
    final sessionChanged = nextUserId != _effectiveCurrentUserId;

    if (requestChanged || sessionChanged) {
      _applySessionOrRequestChange(
        requestChanged: requestChanged,
        sessionChanged: sessionChanged,
        nextUserId: nextUserId,
      );
    }
  }

  void _applySessionOrRequestChange({
    required bool requestChanged,
    required bool sessionChanged,
    required int? nextUserId,
  }) {
    // Batalkan/abaikan seluruh respons dari sesi atau request sebelumnya.
    _requestGeneration++;
    _effectiveCurrentUserId = nextUserId;
    _offers = [];
    _offersPage = 1;
    _hasNextOffersPage = false;
    _isLoadingDetail = false;
    _isLoadingOffers = false;
    _isActionInProgress = false;

    if (requestChanged) {
      _offersClosedLocally = false;
      _request = widget.request;
    } else if (sessionChanged && nextUserId == null) {
      // Saat logout ke mode tamu, bersihkan field privat.
      _request = FoodRequest(
        id: _request.id,
        owner: _request.owner,
        title: _request.title,
        foodItem: _request.foodItem,
        quantity: _request.quantity,
        unit: _request.unit,
        description: _request.description,
        location: _request.location,
        status: _request.status,
        effectiveStatus: _request.effectiveStatus,
        expiresAt: _request.expiresAt,
        offerCount: _request.offerCount,
        hasOffered: false,
        selectedOfferId: null,
        createdAt: _request.createdAt,
        updatedAt: _request.updatedAt,
      );
    }

    if (widget.onRefreshDetail != null || widget.service != null) {
      _refreshDetail();
    } else {
      _initOffersForCurrentSession();
    }
  }

  void _initOffersForCurrentSession() {
    if (!_isOwner) {
      _offers = [];
      _offersPage = 1;
      _hasNextOffersPage = false;
      return;
    }

    if (widget.initialOffers != null) {
      _offers = List<RequestOffer>.from(widget.initialOffers!);
      _offersPage = 1;
      _hasNextOffersPage = widget.initialHasNextOffersPage;
    } else if (widget.onLoadOffers != null || widget.service != null) {
      _loadOffers(page: 1, replace: true);
    } else {
      _offers = getDummyOffersForRequest(_request.id);
      _offersPage = 1;
      _hasNextOffersPage = false;
    }
  }

  void _popParentDeleted([String? message]) {
    if (!mounted) return;
    _showSnackBar(
      message ?? 'Permintaan ini sudah tidak tersedia atau telah dihapus.',
    );
    Navigator.of(context).pop(
      RequestDetailResult(deletedRequestId: _request.id),
    );
  }

  /// Mengecek `GET /api/v1/requests/<id>/` sekali saat menerima `404` ambigu
  /// dari `GET /offers/` atau `PATCH /selection/`.
  Future<void> _handleAmbiguous404({
    required int generation,
    required String whenParentAliveMessage,
  }) async {
    final fetcher = widget.onRefreshDetail ?? widget.service?.fetchRequestDetail;
    if (fetcher == null) {
      _popParentDeleted();
      return;
    }

    try {
      final latest = await fetcher(_request.id);
      if (!mounted || generation != _requestGeneration) return;

      if (latest == null) {
        _popParentDeleted();
        return;
      }

      setState(() {
        _request = latest;
        _hasChanges = true;
        _isActionInProgress = false;
        _isLoadingOffers = false;
      });
      _showSnackBar(whenParentAliveMessage);
      if (_isOwner) {
        await _loadOffers(page: 1, replace: true, allow404Recovery: false);
      }
    } on RequestBoardNotFoundException {
      if (!mounted || generation != _requestGeneration) return;
      _popParentDeleted();
    } catch (e) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _isActionInProgress = false;
        _isLoadingOffers = false;
      });
      _showSnackBar('Gagal memeriksa status permintaan: $e');
    }
  }

  Future<void> _refreshDetail() async {
    final fetcher = widget.onRefreshDetail ?? widget.service?.fetchRequestDetail;
    if (fetcher == null) {
      _initOffersForCurrentSession();
      return;
    }

    final generation = _requestGeneration;
    setState(() => _isLoadingDetail = true);

    try {
      final latest = await fetcher(_request.id);
      if (!mounted || generation != _requestGeneration) return;

      if (latest != null) {
        setState(() {
          _request = latest;
          _isLoadingDetail = false;
        });
      } else {
        setState(() => _isLoadingDetail = false);
      }

      if (_isOwner && (widget.onLoadOffers != null || widget.service != null)) {
        await _loadOffers(page: 1, replace: true);
      } else if (!_isOwner) {
        setState(() {
          _offers = [];
          _offersPage = 1;
          _hasNextOffersPage = false;
        });
      }
    } on RequestBoardNotFoundException {
      if (!mounted || generation != _requestGeneration) return;
      _popParentDeleted();
    } on RequestBoardForbiddenException catch (e) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() => _isLoadingDetail = false);
      _showForbiddenSnackBar(e.message);
    } catch (e) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() => _isLoadingDetail = false);
      _showSnackBar('Gagal menyegarkan detail: $e');
    }
  }

  Future<void> _loadOffers({
    required int page,
    bool replace = false,
    bool allow404Recovery = true,
  }) async {
    if (!_isOwner ||
        (widget.onLoadOffers == null && widget.service == null)) {
      return;
    }

    final generation = _requestGeneration;
    setState(() => _isLoadingOffers = true);

    try {
      final response = widget.onLoadOffers != null
          ? await widget.onLoadOffers!(_request.id, page)
          : await widget.service!.fetchOffers(_request.id, page: page);
      if (!mounted || generation != _requestGeneration) return;

      if (response == null) {
        setState(() => _isLoadingOffers = false);
        return;
      }

      setState(() {
        _offers = replace
            ? List<RequestOffer>.from(response.results)
            : [..._offers, ...response.results];
        _offersPage = response.page;
        _hasNextOffersPage = response.hasNextPage;
        _isLoadingOffers = false;
      });
    } on RequestBoardNotFoundException {
      if (!mounted || generation != _requestGeneration) return;
      if (allow404Recovery) {
        await _handleAmbiguous404(
          generation: generation,
          whenParentAliveMessage:
              'Halaman daftar penawar diperbarui dari awal.',
        );
      } else {
        setState(() => _isLoadingOffers = false);
      }
    } on RequestBoardForbiddenException catch (e) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() => _isLoadingOffers = false);
      _showForbiddenSnackBar(e.message);
    } catch (e) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() => _isLoadingOffers = false);
      _showSnackBar('Gagal memuat daftar penawar: $e');
    }
  }

  Future<void> _handleSubmitOffer() async {
    if (_isGuest || _isOwner || !_request.isActive || _request.hasOffered) {
      return;
    }
    if (_offersClosedLocally || _isActionInProgress) return;

    final generation = _requestGeneration;
    setState(() => _isActionInProgress = true);

    try {
      if (widget.onSubmitOffer != null) {
        final updated = await widget.onSubmitOffer!(_request.id);
        if (!mounted || generation != _requestGeneration) return;
        setState(() {
          if (updated != null) {
            _request = updated;
          } else {
            _request = _copyRequestWith(
              hasOffered: true,
              offerCount: _request.offerCount + 1,
              status: _request.status == 'pending' ? 'offered' : _request.status,
              effectiveStatus: _request.effectiveStatus == 'pending'
                  ? 'offered'
                  : _request.effectiveStatus,
            );
          }
          _hasChanges = true;
          _isActionInProgress = false;
        });
      } else if (widget.service != null) {
        await widget.service!.submitOffer(_request.id);
        if (!mounted || generation != _requestGeneration) return;
        final latest = await widget.service!.fetchRequestDetail(_request.id);
        if (!mounted || generation != _requestGeneration) return;
        setState(() {
          _request = latest;
          _hasChanges = true;
          _isActionInProgress = false;
        });
      } else {
        // Mode lokal Tahap 3 sebelum integrasi API.
        setState(() {
          _request = _copyRequestWith(
            hasOffered: true,
            offerCount: _request.offerCount + 1,
            status: _request.status == 'pending' ? 'offered' : _request.status,
            effectiveStatus: _request.effectiveStatus == 'pending'
                ? 'offered'
                : _request.effectiveStatus,
          );
          _hasChanges = true;
          _isActionInProgress = false;
        });
      }
      _showSnackBar('Penawaran bantuan berhasil dikirim.');
    } on OffersClosedException {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _offersClosedLocally = true;
        _isActionInProgress = false;
      });
      _showSnackBar('Penawaran ditutup oleh pemilik permintaan.');
    } on RequestBoardConflictException catch (e) {
      if (!mounted || generation != _requestGeneration) return;
      if (e.code == 'offers_closed') {
        setState(() {
          _offersClosedLocally = true;
          _isActionInProgress = false;
        });
        _showSnackBar('Penawaran ditutup oleh pemilik permintaan.');
      } else {
        setState(() => _isActionInProgress = false);
        _showSnackBar(e.message);
        if (e.code == 'request_expired' || e.code == 'request_fulfilled') {
          await _refreshDetail();
        }
      }
    } on RequestBoardNotFoundException {
      if (!mounted || generation != _requestGeneration) return;
      _popParentDeleted();
    } on RequestBoardForbiddenException catch (e) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() => _isActionInProgress = false);
      _showForbiddenSnackBar(e.message);
    } catch (e) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() => _isActionInProgress = false);
      _showSnackBar('Gagal mengirim penawaran: $e');
    }
  }

  Future<void> _handleSelectOffer(RequestOffer offer) async {
    if (!_isOwner || !_request.isActive || _isActionInProgress) return;

    final generation = _requestGeneration;
    setState(() => _isActionInProgress = true);

    try {
      final selector = widget.onSelectOffer ?? widget.service?.selectOffer;
      if (selector != null) {
        final updated = await selector(_request.id, offer.id);
        if (!mounted || generation != _requestGeneration) return;
        setState(() {
          _request = updated ?? _copyRequestWith(selectedOfferId: offer.id);
          _hasChanges = true;
          _isActionInProgress = false;
        });
      } else {
        setState(() {
          _request = _copyRequestWith(selectedOfferId: offer.id);
          _hasChanges = true;
          _isActionInProgress = false;
        });
      }
      _showSnackBar(
        'Penawar "${offer.offeredBy.displayName}" dipilih.',
      );
    } on RequestBoardNotFoundException {
      if (!mounted || generation != _requestGeneration) return;
      await _handleAmbiguous404(
        generation: generation,
        whenParentAliveMessage:
            'Penawar yang dipilih sudah tidak tersedia. Daftar penawar disegarkan.',
      );
    } on RequestBoardConflictException catch (e) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() => _isActionInProgress = false);
      _showSnackBar(e.message);
      if (e.code == 'request_expired' || e.code == 'request_fulfilled') {
        await _refreshDetail();
      }
    } on RequestBoardForbiddenException catch (e) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() => _isActionInProgress = false);
      _showForbiddenSnackBar(e.message);
    } catch (e) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() => _isActionInProgress = false);
      _showSnackBar('Gagal memilih penawar: $e');
    }
  }

  Future<void> _handleFulfillRequest() async {
    if (!_isOwner ||
        !_request.isActive ||
        _request.selectedOfferId == null ||
        _isActionInProgress) {
      return;
    }

    final generation = _requestGeneration;
    setState(() => _isActionInProgress = true);

    try {
      final fulfiller =
          widget.onFulfillRequest ?? widget.service?.fulfillRequest;
      if (fulfiller != null) {
        final updated = await fulfiller(_request.id);
        if (!mounted || generation != _requestGeneration) return;
        setState(() {
          _request = updated ??
              _copyRequestWith(
                status: 'fulfilled',
                effectiveStatus: 'fulfilled',
              );
          _hasChanges = true;
          _isActionInProgress = false;
        });
      } else {
        setState(() {
          _request = _copyRequestWith(
            status: 'fulfilled',
            effectiveStatus: 'fulfilled',
          );
          _hasChanges = true;
          _isActionInProgress = false;
        });
      }
      _showSnackBar('Permintaan ditandai terpenuhi.');
    } on RequestBoardNotFoundException {
      if (!mounted || generation != _requestGeneration) return;
      _popParentDeleted();
    } on RequestBoardConflictException catch (e) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() => _isActionInProgress = false);
      _showSnackBar(e.message);
      if (e.code == 'request_expired' || e.code == 'request_fulfilled') {
        await _refreshDetail();
      }
    } on RequestBoardForbiddenException catch (e) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() => _isActionInProgress = false);
      _showForbiddenSnackBar(e.message);
    } catch (e) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() => _isActionInProgress = false);
      _showSnackBar('Gagal menandai terpenuhi: $e');
    }
  }

  Future<void> _handleDeleteRequest() async {
    if (!_isOwner || _isActionInProgress) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Permintaan?'),
        content: Text(
          'Permintaan "${_request.title}" akan dihapus permanen dan tidak '
          'dapat dipulihkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final generation = _requestGeneration;
    setState(() => _isActionInProgress = true);

    try {
      bool deleted = true;
      if (widget.onDeleteRequest != null) {
        deleted = await widget.onDeleteRequest!(_request.id);
      } else if (widget.service != null) {
        await widget.service!.deleteRequest(_request.id);
      }
      if (!mounted || generation != _requestGeneration) return;

      if (deleted) {
        Navigator.of(context).pop(
          RequestDetailResult(deletedRequestId: _request.id),
        );
      } else {
        setState(() => _isActionInProgress = false);
      }
    } on RequestBoardNotFoundException {
      if (!mounted || generation != _requestGeneration) return;
      _popParentDeleted('Permintaan sudah tidak tersedia.');
    } on RequestBoardForbiddenException catch (e) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() => _isActionInProgress = false);
      _showForbiddenSnackBar(e.message);
    } catch (e) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() => _isActionInProgress = false);
      _showSnackBar('Gagal menghapus permintaan: $e');
    }
  }

  void _showForbiddenSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: widget.onNavigateToLogin != null
              ? SnackBarAction(
                  label: 'Masuk',
                  onPressed: widget.onNavigateToLogin!,
                )
              : null,
        ),
      );
  }

  FoodRequest _copyRequestWith({
    String? status,
    String? effectiveStatus,
    int? offerCount,
    bool? hasOffered,
    int? selectedOfferId,
  }) {
    return FoodRequest(
      id: _request.id,
      owner: _request.owner,
      title: _request.title,
      foodItem: _request.foodItem,
      quantity: _request.quantity,
      unit: _request.unit,
      description: _request.description,
      location: _request.location,
      status: status ?? _request.status,
      effectiveStatus: effectiveStatus ?? _request.effectiveStatus,
      expiresAt: _request.expiresAt,
      offerCount: offerCount ?? _request.offerCount,
      hasOffered: hasOffered ?? _request.hasOffered,
      selectedOfferId: selectedOfferId ?? _request.selectedOfferId,
      createdAt: _request.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatQuantity(String raw) {
    final parsed = double.tryParse(raw);
    if (parsed == null) return raw;
    if (parsed == parsed.roundToDouble()) {
      return parsed.toInt().toString();
    }
    return parsed.toString().replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(
          _hasChanges ? RequestDetailResult(updatedRequest: _request) : null,
        );
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: colorScheme.inversePrimary,
          title: const Text('Detail Permintaan'),
          actions: [
            if (widget.onRefreshDetail != null || widget.service != null)
              IconButton(
                tooltip: 'Segarkan',
                onPressed: _isLoadingDetail ? null : _refreshDetail,
                icon: _isLoadingDetail
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isTabletWide = constraints.maxWidth >= 720;
              final isTablet = constraints.maxWidth >= 600;

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 24 : 16,
                  vertical: 16,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 840),
                    child: isTabletWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 6,
                                child: _buildDetailCard(context),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 5,
                                child: _buildRoleSection(context),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildDetailCard(context),
                              const SizedBox(height: 16),
                              _buildRoleSection(context),
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: requestCardHeroTag(_request.id),
              child: Material(
                type: MaterialType.transparency,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _request.title,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    RequestStatusBadge(
                      effectiveStatus: _request.effectiveStatus,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DetailPill(
                  icon: Icons.restaurant_outlined,
                  label: _request.foodItem,
                ),
                _DetailPill(
                  icon: Icons.scale_outlined,
                  label:
                      '${_formatQuantity(_request.quantity)} ${_request.unit}',
                ),
                _DetailPill(
                  icon: Icons.volunteer_activism_outlined,
                  label: '${_request.offerCount} penawaran',
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Text(
              'Deskripsi',
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _request.description.trim().isNotEmpty
                  ? _request.description
                  : 'Tidak ada deskripsi tambahan.',
              style: textTheme.bodyMedium?.copyWith(
                color: _request.description.trim().isNotEmpty
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _DetailInfoRow(
              icon: Icons.person_outline,
              label: 'Pemohon',
              value: _isOwner
                  ? '${_request.owner.displayName} (Anda)'
                  : _request.owner.displayName,
            ),
            const SizedBox(height: 10),
            _DetailInfoRow(
              icon: Icons.location_on_outlined,
              label: 'Lokasi',
              value: _request.location.trim().isNotEmpty
                  ? _request.location
                  : 'Lokasi belum ditentukan',
            ),
            const SizedBox(height: 10),
            _DetailInfoRow(
              icon: Icons.schedule_outlined,
              label: 'Tenggat Waktu',
              value: _request.expiresAt != null
                  ? _formatDateTime(_request.expiresAt!)
                  : 'Tanpa tenggat',
            ),
            const SizedBox(height: 10),
            _DetailInfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Dibuat Pada',
              value: _formatDateTime(_request.createdAt),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSection(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _isGuest
          ? _buildGuestSection(context)
          : _isOwner
              ? _buildOwnerSection(context)
              : _buildNonOwnerSection(context),
    );
  }

  Widget _buildGuestSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      key: const ValueKey('guest-section'),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_outline, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mode Tamu',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Masuk ke akun SaveBite untuk menawarkan bantuan pada permintaan '
              'ini atau mengelola penawaran.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (widget.onNavigateToLogin != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.onNavigateToLogin,
                  icon: const Icon(Icons.login),
                  label: const Text('Masuk untuk Berkontribusi'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNonOwnerSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final canOffer = _request.isActive &&
        !_request.hasOffered &&
        !_offersClosedLocally &&
        !_isActionInProgress;

    String statusNotice;
    IconData noticeIcon;
    Color noticeColor;

    if (_offersClosedLocally) {
      statusNotice = 'Penawaran ditutup';
      noticeIcon = Icons.block_outlined;
      noticeColor = colorScheme.error;
    } else if (_request.hasOffered) {
      statusNotice = 'Anda sudah menawarkan bantuan untuk permintaan ini.';
      noticeIcon = Icons.check_circle_outline;
      noticeColor = colorScheme.primary;
    } else if (!_request.isActive) {
      statusNotice = _request.effectiveStatus == 'fulfilled'
          ? 'Permintaan ini sudah terpenuhi.'
          : 'Permintaan ini sudah kedaluwarsa.';
      noticeIcon = Icons.info_outline;
      noticeColor = colorScheme.onSurfaceVariant;
    } else {
      statusNotice =
          'Anda dapat menawarkan bantuan untuk memenuhi permintaan bahan ini.';
      noticeIcon = Icons.volunteer_activism_outlined;
      noticeColor = colorScheme.primary;
    }

    return Card(
      key: ValueKey(
        'non-owner-${_request.effectiveStatus}-${_request.hasOffered}-$_offersClosedLocally',
      ),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(noticeIcon, color: noticeColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    statusNotice,
                    style: textTheme.bodyMedium?.copyWith(
                      color: noticeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: canOffer ? _handleSubmitOffer : null,
              icon: _isActionInProgress
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.volunteer_activism_outlined),
              label: Text(
                _offersClosedLocally
                    ? 'Penawaran ditutup'
                    : _request.hasOffered
                        ? 'Sudah Menawarkan'
                        : 'Tawarkan Bantuan',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final canFulfill = _request.isActive &&
        _request.selectedOfferId != null &&
        !_isActionInProgress;
    final canDelete = !_isActionInProgress;

    return Column(
      key: ValueKey(
        'owner-${_request.effectiveStatus}-${_request.selectedOfferId}-${_offers.length}',
      ),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Kelola Permintaan',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: canFulfill ? _handleFulfillRequest : null,
                  icon: const Icon(Icons.task_alt_outlined),
                  label: const Text('Tandai Terpenuhi'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(color: colorScheme.error),
                  ),
                  onPressed: canDelete ? _handleDeleteRequest : null,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Hapus Request'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Daftar Penawaran (${_request.offerCount})',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (_isLoadingOffers && _offers.isNotEmpty)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_isLoadingOffers && _offers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_offers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Belum ada penawaran masuk untuk permintaan ini.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      for (var i = 0; i < _offers.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        OfferCard(
                          offer: _offers[i],
                          // Penanda terpilih wajib berasal dari selectedOfferId.
                          isSelected:
                              _offers[i].id == _request.selectedOfferId,
                          hasAnySelectedOffer:
                              _request.selectedOfferId != null,
                          canSelect: _request.isActive && !_isActionInProgress,
                          isSubmitting: _isActionInProgress,
                          onSelect: () => _handleSelectOffer(_offers[i]),
                        ),
                      ],
                    ],
                  ),
                if (_hasNextOffersPage) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isLoadingOffers
                        ? null
                        : () => _loadOffers(page: _offersPage + 1),
                    icon: const Icon(Icons.expand_more),
                    label: const Text('Muat Penawar Berikutnya'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
