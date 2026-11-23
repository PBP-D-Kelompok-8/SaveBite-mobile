import 'package:flutter/material.dart';
import 'package:savebite_mobile/request_board/data/dummy_requests.dart';
import 'package:savebite_mobile/request_board/models/food_request.dart';
import 'package:savebite_mobile/request_board/services/idempotency_draft_store.dart';
import 'package:savebite_mobile/request_board/services/request_board_service.dart';
import 'package:savebite_mobile/request_board/services/session_client.dart';

/// Exception untuk error validasi per field dari server (`400 Bad Request`).
class RequestFormValidationException implements Exception {
  final Map<String, String> fieldErrors;
  final String? generalError;

  const RequestFormValidationException({
    this.fieldErrors = const {},
    this.generalError,
  });

  @override
  String toString() =>
      generalError ?? 'Validasi gagal pada beberapa field formulir.';
}

/// Halaman form multi-langkah (`Stepper` 2 langkah) untuk membuat
/// [FoodRequest] baru sesuai aturan validasi `request_board/validators.py`.
class RequestFormPage extends StatefulWidget {
  final int? currentUserId;
  final String currentUserDisplayName;

  /// Callback opsional untuk integrasi API di Tahap 4.
  /// Jika null dan [service] juga null, form mengembalikan [FoodRequest] lokal.
  final Future<FoodRequest?> Function(FoodRequestCreatePayload payload)?
      onSubmit;

  /// Service REST API untuk submit form dengan idempotensi `Idempotency-Key`.
  final RequestBoardService? service;

  /// Penyimpanan draf idempoten lintas sesi (opsional untuk pengujian).
  final PendingRequestDraftStore? draftStore;

  /// Opsional untuk pengujian atau injeksi generator UUID v4.
  final String Function()? idempotencyKeyGenerator;

  /// Opsional untuk pengujian atau injeksi waktu sekarang.
  final DateTime Function()? nowProvider;

  const RequestFormPage({
    super.key,
    this.currentUserId = dummyCurrentUserId,
    this.currentUserDisplayName = 'Dapur Komunitas Menteng',
    this.onSubmit,
    this.service,
    this.draftStore,
    this.idempotencyKeyGenerator,
    this.nowProvider,
  });

  @override
  State<RequestFormPage> createState() => _RequestFormPageState();
}

class _RequestFormPageState extends State<RequestFormPage> {
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _foodItemController = TextEditingController();
  final _quantityController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  int _currentStep = 0;
  String? _selectedUnit;
  DateTime? _expiresAt;
  String? _expiresAtLocalError;
  Map<String, String> _serverErrors = {};
  String? _generalError;
  bool _isSubmitting = false;

  late String _idempotencyKey;
  FoodRequestCreatePayload? _lockedPayload;
  PendingRequestDraftStore? _draftStore;

  DateTime get _now => (widget.nowProvider ?? DateTime.now)();

  String _nextUuid() =>
      (widget.idempotencyKeyGenerator ?? generateUuidV4)();

  @override
  void initState() {
    super.initState();
    _idempotencyKey = _nextUuid();
    if (widget.service != null) {
      _draftStore = widget.draftStore ?? PendingRequestDraftStore();
      _restorePendingDraft();
    }
  }

  Future<void> _restorePendingDraft() async {
    final accountId =
        widget.currentUserId ?? widget.service?.sessionClient.currentUserId;
    if (accountId == null || _draftStore == null) return;

    final draft = await _draftStore!.loadForAccount(accountId, now: _now);
    if (!mounted || draft == null) return;

    final restoredPayload = draft.toPayload();
    setState(() {
      _idempotencyKey = draft.idempotencyKey;
      _lockedPayload = restoredPayload;
      if (_titleController.text.isEmpty) {
        _titleController.text = restoredPayload.title;
      }
      if (_foodItemController.text.isEmpty) {
        _foodItemController.text = restoredPayload.foodItem;
      }
      if (_quantityController.text.isEmpty) {
        _quantityController.text = restoredPayload.quantity;
      }
      _selectedUnit ??= restoredPayload.unit;
      if (_locationController.text.isEmpty) {
        _locationController.text = restoredPayload.location;
      }
      if (_descriptionController.text.isEmpty) {
        _descriptionController.text = restoredPayload.description;
      }
      _expiresAt ??= restoredPayload.expiresAt;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _foodItemController.dispose();
    _quantityController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _clearServerError(String field) {
    if (_serverErrors.containsKey(field) || _generalError != null) {
      setState(() {
        _serverErrors.remove(field);
        _generalError = null;
      });
    }
  }

  String? _validateTitle(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Judul permintaan wajib diisi.';
    }
    if (trimmed.length > 120) {
      return 'Judul maksimal 120 karakter.';
    }
    return null;
  }

  String? _validateFoodItem(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Nama bahan makanan wajib diisi.';
    }
    if (trimmed.length > 120) {
      return 'Nama bahan makanan maksimal 120 karakter.';
    }
    return null;
  }

  String? _validateQuantity(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Jumlah wajib diisi.';
    }
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(trimmed)) {
      return 'Gunakan angka valid dengan maksimal 2 angka desimal (mis. 2.50).';
    }
    final parsed = double.tryParse(trimmed);
    if (parsed == null || parsed < 0.01 || parsed > 999999.99) {
      return 'Jumlah harus antara 0.01 dan 999999.99.';
    }
    return null;
  }

  String? _validateUnit(String? value) {
    if (value == null || !unitChoices.contains(value)) {
      return 'Pilih satuan bahan makanan.';
    }
    return null;
  }

  String? _validateLocation(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.length > 120) {
      return 'Lokasi maksimal 120 karakter.';
    }
    return null;
  }

  String? _validateDescription(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.length > 1000) {
      return 'Deskripsi maksimal 1.000 karakter.';
    }
    return null;
  }

  bool _validateExpiresAt() {
    if (_expiresAt == null) {
      setState(() => _expiresAtLocalError = null);
      return true;
    }
    if (!_expiresAt!.isAfter(_now)) {
      setState(() {
        _expiresAtLocalError = 'Tenggat waktu harus di masa depan.';
      });
      return false;
    }
    setState(() => _expiresAtLocalError = null);
    return true;
  }

  bool _validateStep1() {
    return _step1FormKey.currentState?.validate() ?? false;
  }

  bool _validateStep2() {
    final formValid = _step2FormKey.currentState?.validate() ?? false;
    final expiresValid = _validateExpiresAt();
    return formValid && expiresValid;
  }

  Future<void> _pickExpiresAt() async {
    final now = _now;
    final initial = _expiresAt != null && _expiresAt!.isAfter(now)
        ? _expiresAt!
        : now.add(const Duration(hours: 24));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2, now.month, now.day),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null || !mounted) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      _expiresAt = combined;
      _serverErrors.remove('expires_at');
      _generalError = null;
    });
    _validateExpiresAt();
  }

  FoodRequestCreatePayload _buildPayload() {
    final parsedQty = double.parse(_quantityController.text.trim());
    return FoodRequestCreatePayload(
      title: _titleController.text.trim(),
      foodItem: _foodItemController.text.trim(),
      quantity: parsedQty.toStringAsFixed(2),
      unit: _selectedUnit!,
      description: _descriptionController.text.trim(),
      location: _locationController.text.trim(),
      expiresAt: _expiresAt,
    );
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;
    if (!_validateStep1()) {
      setState(() => _currentStep = 0);
      return;
    }
    if (!_validateStep2()) {
      return;
    }

    final payload = _buildPayload();
    setState(() {
      _isSubmitting = true;
      _serverErrors = {};
      _generalError = null;
    });

    try {
      if (widget.onSubmit != null) {
        final created = await widget.onSubmit!(payload);
        if (!mounted) return;
        Navigator.of(context).pop(created);
      } else if (widget.service != null) {
        await _submitViaService(payload);
      } else {
        final nowUtc = _now.toUtc();
        final localCreated = FoodRequest(
          id: nowUtc.millisecondsSinceEpoch,
          owner: RequestOwner(
            id: widget.currentUserId ?? dummyCurrentUserId,
            displayName: widget.currentUserDisplayName,
          ),
          title: payload.title,
          foodItem: payload.foodItem,
          quantity: payload.quantity,
          unit: payload.unit,
          description: payload.description,
          location: payload.location,
          status: 'pending',
          effectiveStatus: 'pending',
          expiresAt: payload.expiresAt?.toUtc() ??
              nowUtc.add(const Duration(hours: 24)),
          offerCount: 0,
          hasOffered: false,
          selectedOfferId: null,
          createdAt: nowUtc,
          updatedAt: nowUtc,
        );
        Navigator.of(context).pop(localCreated);
      }
    } on RequestFormValidationException catch (e) {
      if (!mounted) return;
      final step1Fields = {'title', 'food_item', 'quantity', 'unit'};
      final hasStep1Error = e.fieldErrors.keys.any(step1Fields.contains);

      setState(() {
        _serverErrors = Map<String, String>.from(e.fieldErrors);
        _generalError = e.generalError;
        _isSubmitting = false;
        if (hasStep1Error) {
          _currentStep = 0;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generalError = 'Gagal mengirim permintaan: $e';
        _isSubmitting = false;
      });
    }
  }

  Future<void> _submitViaService(FoodRequestCreatePayload formPayload) async {
    final service = widget.service!;
    final accountId =
        widget.currentUserId ?? service.sessionClient.currentUserId;

    // Pertahankan salinan payload pertama & UUID selama hasil belum pasti.
    final payloadToSend = _lockedPayload ?? formPayload;
    _lockedPayload ??= payloadToSend;

    if (accountId != null && _draftStore != null) {
      await _draftStore!.save(
        PendingRequestDraft(
          accountId: accountId,
          idempotencyKey: _idempotencyKey,
          payloadJson: payloadToSend.toJson(),
          createdAt: _now.toUtc(),
        ),
      );
    }

    try {
      final created = await service.createRequest(
        payloadToSend,
        idempotencyKey: _idempotencyKey,
      );
      await _draftStore?.clear();
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } on RequestBoardValidationException catch (e) {
      await _draftStore?.clear();
      _lockedPayload = null;
      if (!mounted) return;
      final step1Fields = {'title', 'food_item', 'quantity', 'unit'};
      final hasStep1Error = e.fieldErrors.keys.any(step1Fields.contains);

      setState(() {
        _serverErrors = Map<String, String>.from(e.fieldErrors);
        _generalError = e.fieldErrors.isEmpty ? e.message : null;
        _isSubmitting = false;
        if (hasStep1Error) {
          _currentStep = 0;
        }
      });
    } on RequestBoardForbiddenException catch (e) {
      await _draftStore?.clear();
      _lockedPayload = null;
      if (!mounted) return;
      setState(() {
        _generalError = e.message;
        _isSubmitting = false;
      });
    } on RequestBoardConflictException catch (e) {
      await _draftStore?.clear();
      _lockedPayload = null;
      if (e.code == 'idempotency_conflict' || e.code == 'idempotency_deleted') {
        _idempotencyKey = _nextUuid();
      }
      if (!mounted) return;
      setState(() {
        _generalError = e.message;
        _isSubmitting = false;
      });
    } on RequestBoardNetworkException {
      await _reconcileIdempotencyAfterNetworkError(service);
    } on RequestBoardApiException catch (e) {
      await _draftStore?.clear();
      _lockedPayload = null;
      if (!mounted) return;
      setState(() {
        _generalError = e.message;
        _isSubmitting = false;
      });
    }
  }

  Future<void> _reconcileIdempotencyAfterNetworkError(
    RequestBoardService service,
  ) async {
    try {
      final status = await service.fetchRequestCreationStatus(_idempotencyKey);
      if (!mounted) return;

      if (status != null && status.isCreated) {
        FoodRequest? created;
        if (status.requestId != null) {
          try {
            created = await service.fetchRequestDetail(status.requestId!);
          } catch (_) {
            // Tetap selesaikan alur sukses bila detail gagal dimuat ulang.
          }
        }
        await _draftStore?.clear();
        _lockedPayload = null;
        if (!mounted) return;
        Navigator.of(context).pop(created);
        return;
      }

      if (status != null && status.isDeleted) {
        await _draftStore?.clear();
        _lockedPayload = null;
        _idempotencyKey = _nextUuid();
        setState(() {
          _generalError =
              'Permintaan dari pengajuan sebelumnya sudah dihapus. Retry dihentikan.';
          _isSubmitting = false;
        });
        return;
      }

      // status == null (404): hasil masih belum pasti -> pertahankan key & payload.
      setState(() {
        _generalError =
            'Hasil pengiriman belum pasti karena gangguan jaringan. Tekan "Kirim Permintaan" untuk mencoba ulang dengan data yang sama.';
        _isSubmitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Lookup juga gagal jaringan -> pertahankan key & payload untuk retry.
      setState(() {
        _generalError =
            'Koneksi terputus saat memeriksa status pengiriman. Tekan "Kirim Permintaan" untuk mencoba ulang dengan data yang sama.';
        _isSubmitting = false;
      });
    }
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
    final expiresErrorText = _expiresAtLocalError ?? _serverErrors['expires_at'];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.inversePrimary,
        title: const Text('Buat Permintaan Baru'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_lockedPayload != null && _generalError == null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.sync_problem_outlined,
                            color: colorScheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Melanjutkan pengajuan sebelumnya dengan kunci idempotensi yang sama.',
                              style: TextStyle(
                                color: colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_generalError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _generalError!,
                              style: TextStyle(
                                color: colorScheme.onErrorContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Stepper(
                    physics: const NeverScrollableScrollPhysics(),
                    currentStep: _currentStep,
                    onStepTapped: (step) {
                      if (_isSubmitting) return;
                      if (step == 1 && !_validateStep1()) return;
                      setState(() => _currentStep = step);
                    },
                    onStepContinue: () {
                      if (_currentStep == 0) {
                        if (_validateStep1()) {
                          setState(() => _currentStep = 1);
                        }
                      } else {
                        _handleSubmit();
                      }
                    },
                    onStepCancel: () {
                      if (_currentStep == 0) {
                        Navigator.of(context).pop();
                      } else {
                        setState(() => _currentStep = 0);
                      }
                    },
                    controlsBuilder: (context, details) {
                      final isLastStep = details.stepIndex == 1;
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed:
                                  _isSubmitting ? null : details.onStepContinue,
                              icon: _isSubmitting && isLastStep
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      isLastStep
                                          ? Icons.send_outlined
                                          : Icons.arrow_forward,
                                    ),
                              label: Text(
                                isLastStep ? 'Kirim Permintaan' : 'Lanjut',
                              ),
                            ),
                            OutlinedButton(
                              onPressed:
                                  _isSubmitting ? null : details.onStepCancel,
                              child: Text(isLastStep ? 'Kembali' : 'Batal'),
                            ),
                          ],
                        ),
                      );
                    },
                    steps: [
                      Step(
                        title: const Text('Detail Bahan'),
                        subtitle: const Text(
                          'Judul, bahan makanan, jumlah, dan satuan',
                        ),
                        isActive: _currentStep >= 0,
                        state: _currentStep > 0
                            ? StepState.complete
                            : StepState.indexed,
                        content: Form(
                          key: _step1FormKey,
                          child: Column(
                            children: [
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _titleController,
                                maxLength: 120,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'Judul Permintaan *',
                                  hintText:
                                      'Contoh: Butuh Beras Putih untuk Dapur Umum',
                                  border: const OutlineInputBorder(),
                                  errorText: _serverErrors['title'],
                                ),
                                validator: _validateTitle,
                                onChanged: (_) => _clearServerError('title'),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _foodItemController,
                                maxLength: 120,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'Nama Bahan Makanan *',
                                  hintText: 'Contoh: Beras Putih Medium',
                                  border: const OutlineInputBorder(),
                                  errorText: _serverErrors['food_item'],
                                ),
                                validator: _validateFoodItem,
                                onChanged: (_) =>
                                    _clearServerError('food_item'),
                              ),
                              const SizedBox(height: 12),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final qtyField = TextFormField(
                                    controller: _quantityController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    textInputAction: TextInputAction.next,
                                    decoration: InputDecoration(
                                      labelText: 'Jumlah *',
                                      hintText: '0.01 - 999999.99',
                                      border: const OutlineInputBorder(),
                                      errorText: _serverErrors['quantity'],
                                    ),
                                    validator: _validateQuantity,
                                    onChanged: (_) =>
                                        _clearServerError('quantity'),
                                  );

                                  final unitField =
                                      DropdownButtonFormField<String>(
                                    initialValue: _selectedUnit,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: 'Satuan *',
                                      border: const OutlineInputBorder(),
                                      errorText: _serverErrors['unit'],
                                    ),
                                    items: unitChoices
                                        .map(
                                          (unit) => DropdownMenuItem<String>(
                                            value: unit,
                                            child: Text(unit),
                                          ),
                                        )
                                        .toList(),
                                    validator: _validateUnit,
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedUnit = value;
                                        _serverErrors.remove('unit');
                                        _generalError = null;
                                      });
                                    },
                                  );

                                  if (constraints.maxWidth < 420) {
                                    return Column(
                                      children: [
                                        qtyField,
                                        const SizedBox(height: 12),
                                        unitField,
                                      ],
                                    );
                                  }

                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: qtyField),
                                      const SizedBox(width: 12),
                                      Expanded(child: unitField),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      Step(
                        title: const Text('Lokasi, Deskripsi, & Tenggat'),
                        subtitle: const Text(
                          'Informasi tambahan dan ringkasan',
                        ),
                        isActive: _currentStep >= 1,
                        content: Form(
                          key: _step2FormKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _locationController,
                                maxLength: 120,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'Lokasi (Opsional)',
                                  hintText: 'Contoh: Menteng, Jakarta Pusat',
                                  border: const OutlineInputBorder(),
                                  errorText: _serverErrors['location'],
                                ),
                                validator: _validateLocation,
                                onChanged: (_) => _clearServerError('location'),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _descriptionController,
                                maxLength: 1000,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  labelText: 'Deskripsi (Opsional)',
                                  hintText:
                                      'Tambahkan detail kebutuhan atau catatan penjemputan...',
                                  alignLabelWithHint: true,
                                  border: const OutlineInputBorder(),
                                  errorText: _serverErrors['description'],
                                ),
                                validator: _validateDescription,
                                onChanged: (_) =>
                                    _clearServerError('description'),
                              ),
                              const SizedBox(height: 12),
                              InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Tenggat Waktu (Opsional)',
                                  border: const OutlineInputBorder(),
                                  errorText: expiresErrorText,
                                  helperText:
                                      'Jika dikosongkan, server otomatis memberi tenggat +24 jam.',
                                  helperMaxLines: 2,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _expiresAt != null
                                            ? _formatDateTime(_expiresAt!)
                                            : 'Default (+24 jam dari pembuatan)',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: _expiresAt != null
                                                  ? colorScheme.onSurface
                                                  : colorScheme
                                                      .onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                                    if (_expiresAt != null)
                                      IconButton(
                                        tooltip: 'Hapus Tenggat',
                                        onPressed: () {
                                          setState(() {
                                            _expiresAt = null;
                                            _expiresAtLocalError = null;
                                            _serverErrors.remove('expires_at');
                                          });
                                        },
                                        icon: const Icon(Icons.close),
                                      ),
                                    TextButton.icon(
                                      onPressed: _pickExpiresAt,
                                      icon: const Icon(
                                        Icons.calendar_today_outlined,
                                        size: 18,
                                      ),
                                      label: Text(
                                        _expiresAt != null ? 'Ubah' : 'Pilih',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              _SummaryCard(
                                title: _titleController.text.trim(),
                                foodItem: _foodItemController.text.trim(),
                                quantity: _quantityController.text.trim(),
                                unit: _selectedUnit ?? '-',
                                location: _locationController.text.trim(),
                                expiresAtLabel: _expiresAt != null
                                    ? _formatDateTime(_expiresAt!)
                                    : 'Default (+24 jam)',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String foodItem;
  final String quantity;
  final String unit;
  final String location;
  final String expiresAtLabel;

  const _SummaryCard({
    required this.title,
    required this.foodItem,
    required this.quantity,
    required this.unit,
    required this.location,
    required this.expiresAtLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ringkasan Permintaan',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _SummaryRow(label: 'Judul', value: title.isNotEmpty ? title : '-'),
          _SummaryRow(
            label: 'Bahan',
            value: foodItem.isNotEmpty ? foodItem : '-',
          ),
          _SummaryRow(
            label: 'Jumlah',
            value: quantity.isNotEmpty ? '$quantity $unit' : '-',
          ),
          _SummaryRow(
            label: 'Lokasi',
            value: location.isNotEmpty ? location : 'Belum ditentukan',
          ),
          _SummaryRow(label: 'Tenggat', value: expiresAtLabel),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
