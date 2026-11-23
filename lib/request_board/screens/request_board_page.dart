import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:savebite_mobile/request_board/models/food_request.dart';
import 'package:savebite_mobile/request_board/providers/request_board_provider.dart';
import 'package:savebite_mobile/request_board/screens/request_detail_page.dart';
import 'package:savebite_mobile/request_board/screens/request_form_page.dart';
import 'package:savebite_mobile/request_board/services/request_board_service.dart';
import 'package:savebite_mobile/request_board/widgets/request_card.dart';
import 'package:savebite_mobile/request_board/widgets/request_filter_bar.dart';
import 'package:savebite_mobile/widgets/left_drawer.dart';

/// Halaman utama daftar permintaan bahan makanan pada modul Request Board.
class RequestBoardPage extends StatefulWidget {
  final RequestBoardProvider? provider;
  final RequestBoardService? service;
  final VoidCallback? onNavigateToLogin;

  const RequestBoardPage({
    super.key,
    this.provider,
    this.service,
    this.onNavigateToLogin,
  });

  @override
  State<RequestBoardPage> createState() => _RequestBoardPageState();
}

class _RequestBoardPageState extends State<RequestBoardPage> {
  final ScrollController _scrollController = ScrollController();

  RequestBoardProvider? _ownedProvider;
  RequestBoardProvider? _activeProvider;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final resolved = _resolveProvider();
    if (!identical(resolved, _activeProvider)) {
      _activeProvider = resolved;
      if (resolved.boardStatus == RequestBoardStatus.initial) {
        Future.microtask(() {
          if (mounted) {
            resolved.loadRequests();
          }
        });
      }
    }
  }

  RequestBoardProvider _resolveProvider() {
    if (widget.provider != null) {
      return widget.provider!;
    }

    if (widget.service != null) {
      return _ownedProvider ??= RequestBoardProvider(service: widget.service!);
    }

    final contextProvider = Provider.of<RequestBoardProvider?>(
      context,
      listen: false,
    );
    if (contextProvider != null) {
      return contextProvider;
    }

    return _ownedProvider ??= RequestBoardProvider(
      service: RequestBoardService(),
    );
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _ownedProvider?.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final provider = _activeProvider;
    if (provider == null || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200 &&
        provider.hasNextPage &&
        !provider.isLoadingMore &&
        !provider.isLoading) {
      provider.loadNextPage();
    }
  }

  PageRouteBuilder<T> _buildSmoothRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 240),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _openRequestDetail(
    RequestBoardProvider provider,
    FoodRequest request,
  ) async {
    final result = await Navigator.of(context).push<RequestDetailResult>(
      _buildSmoothRoute(
        RequestDetailPage(
          request: request,
          currentUserId: provider.currentUserId,
          service: provider.service,
          onNavigateToLogin: widget.onNavigateToLogin,
        ),
      ),
    );

    if (!mounted || result == null) return;

    if (result.deletedRequestId != null) {
      provider.removeRequestById(result.deletedRequestId!);
      _showSnackBar('Permintaan berhasil dihapus.');
    } else if (result.updatedRequest != null) {
      provider.upsertRequest(result.updatedRequest!);
    }
  }

  Future<void> _openCreateForm(RequestBoardProvider provider) async {
    if (!provider.isAuthenticated) {
      _showSnackBar(
        'Silakan masuk terlebih dahulu untuk membuat permintaan.',
        actionLabel: widget.onNavigateToLogin != null ? 'Masuk' : null,
        onAction: widget.onNavigateToLogin,
      );
      return;
    }

    final created = await Navigator.of(context).push<FoodRequest>(
      _buildSmoothRoute(
        RequestFormPage(
          currentUserId: provider.currentUserId,
          currentUserDisplayName:
              provider.sessionClient.currentUsername ?? 'Pengguna SaveBite',
          service: provider.service,
        ),
      ),
    );

    if (!mounted || created == null) return;

    provider.upsertRequest(created);
    _showSnackBar('Permintaan "${created.title}" berhasil dibuat.');
  }

  void _showSnackBar(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: (actionLabel != null && onAction != null)
              ? SnackBarAction(label: actionLabel, onPressed: onAction)
              : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final provider = _activeProvider ?? _resolveProvider();

    return ChangeNotifierProvider<RequestBoardProvider>.value(
      value: provider,
      child: Consumer<RequestBoardProvider>(
        builder: (context, board, _) {
          final colorScheme = Theme.of(context).colorScheme;

          return Scaffold(
            appBar: AppBar(
              backgroundColor: colorScheme.inversePrimary,
              title: const Text('Food Rescue Request Board'),
            ),
            drawer: const LeftDrawer(),
            floatingActionButton: FloatingActionButton(
              tooltip: 'Buat Permintaan Baru',
              onPressed: () => _openCreateForm(board),
              child: const Icon(Icons.add),
            ),
            body: Column(
              children: [
                if (board.isOfflineCached)
                  _OfflineCacheBanner(onRetry: board.refresh),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: RequestFilterBar(
                    initialQuery: board.query,
                    selectedStatus: board.selectedStatus,
                    mineOnly: board.mineOnly,
                    isAuthenticated: board.isAuthenticated,
                    selectedSort: board.selectedSort,
                    onSearchChanged: board.setSearchQuery,
                    onStatusChanged: board.setStatusFilter,
                    onMineChanged: board.setMineOnly,
                    onSortChanged: board.setSort,
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _buildBodyState(context, board),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBodyState(BuildContext context, RequestBoardProvider board) {
    if (board.isLoading && board.requests.isEmpty) {
      return const Center(
        key: ValueKey('loading'),
        child: CircularProgressIndicator(),
      );
    }

    if (board.hasError && board.requests.isEmpty) {
      return _ErrorBoardState(
        key: const ValueKey('error'),
        message: board.errorMessage ?? 'Gagal memuat daftar permintaan.',
        isForbidden: board.isForbiddenError,
        onRetry: board.refresh,
        onLogin: widget.onNavigateToLogin,
      );
    }

    final requests = board.requests;
    if (requests.isEmpty) {
      return RefreshIndicator(
        key: const ValueKey('empty'),
        onRefresh: board.refresh,
        child: _EmptyBoardState(
          hasActiveFilter: board.hasActiveFilter,
          onResetFilters: board.resetFilters,
        ),
      );
    }

    final hasFooter = board.hasNextPage || board.isLoadingMore;

    return RefreshIndicator(
      key: const ValueKey('list'),
      onRefresh: board.refresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            return ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
              itemCount: requests.length + (hasFooter ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= requests.length) {
                  return _PaginationFooter(
                    isLoadingMore: board.isLoadingMore,
                    onLoadMore: board.loadNextPage,
                  );
                }
                final request = requests[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: RequestCard(
                    request: request,
                    onTap: () => _openRequestDetail(board, request),
                  ),
                );
              },
            );
          }

          return CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  4,
                  16,
                  hasFooter ? 12 : 88,
                ),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final request = requests[index];
                      return RequestCard(
                        request: request,
                        onTap: () => _openRequestDetail(board, request),
                      );
                    },
                    childCount: requests.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 240,
                  ),
                ),
              ),
              if (hasFooter)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                  sliver: SliverToBoxAdapter(
                    child: _PaginationFooter(
                      isLoadingMore: board.isLoadingMore,
                      onLoadMore: board.loadNextPage,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _OfflineCacheBanner extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _OfflineCacheBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      color: colorScheme.tertiaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 20,
            color: colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Mode Offline — menampilkan data terakhir tersimpan',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onRetry,
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}

class _PaginationFooter extends StatelessWidget {
  final bool isLoadingMore;
  final Future<void> Function() onLoadMore;

  const _PaginationFooter({
    required this.isLoadingMore,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: isLoadingMore
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : OutlinedButton.icon(
                onPressed: onLoadMore,
                icon: const Icon(Icons.expand_more),
                label: const Text('Muat Lebih Banyak'),
              ),
      ),
    );
  }
}

class _ErrorBoardState extends StatelessWidget {
  final String message;
  final bool isForbidden;
  final Future<void> Function() onRetry;
  final VoidCallback? onLogin;

  const _ErrorBoardState({
    super.key,
    required this.message,
    required this.isForbidden,
    required this.onRetry,
    this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isForbidden
                  ? Icons.lock_outline_rounded
                  : Icons.error_outline_rounded,
              size: 56,
              color: colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              isForbidden
                  ? 'Sesi diperlukan untuk melihat data ini'
                  : 'Gagal memuat Request Board',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba Lagi'),
                ),
                if (isForbidden && onLogin != null)
                  OutlinedButton.icon(
                    onPressed: onLogin,
                    icon: const Icon(Icons.login),
                    label: const Text('Masuk'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBoardState extends StatelessWidget {
  final bool hasActiveFilter;
  final Future<void> Function() onResetFilters;

  const _EmptyBoardState({
    required this.hasActiveFilter,
    required this.onResetFilters,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 56,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      hasActiveFilter
                          ? 'Tidak ada permintaan yang cocok'
                          : 'Belum ada permintaan bahan makanan',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasActiveFilter
                          ? 'Coba ubah kata kunci pencarian atau filter status.'
                          : 'Permintaan bahan makanan yang dibuat komunitas akan muncul di sini.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (hasActiveFilter) ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: onResetFilters,
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        label: const Text('Reset Filter'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
