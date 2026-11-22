import 'package:flutter/material.dart';
import 'package:savebite_mobile/request_board/data/dummy_requests.dart';
import 'package:savebite_mobile/request_board/models/food_request.dart';
import 'package:savebite_mobile/request_board/widgets/request_card.dart';
import 'package:savebite_mobile/request_board/widgets/request_filter_bar.dart';
import 'package:savebite_mobile/widgets/left_drawer.dart';

/// Halaman utama daftar permintaan bahan makanan pada modul Request Board.
class RequestBoardPage extends StatefulWidget {
  final List<FoodRequest>? initialRequests;
  final int? currentUserId;
  final bool isLoading;

  const RequestBoardPage({
    super.key,
    this.initialRequests,
    this.currentUserId = dummyCurrentUserId,
    this.isLoading = false,
  });

  @override
  State<RequestBoardPage> createState() => _RequestBoardPageState();
}

class _RequestBoardPageState extends State<RequestBoardPage> {
  String _query = '';
  String? _selectedStatus;
  bool _mineOnly = false;
  String _selectedSort = 'newest';
  late bool _isLoading;

  @override
  void initState() {
    super.initState();
    _isLoading = widget.isLoading;
  }

  @override
  void didUpdateWidget(covariant RequestBoardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading != oldWidget.isLoading) {
      _isLoading = widget.isLoading;
    }
    if (widget.currentUserId == null && _mineOnly) {
      _mineOnly = false;
    }
  }

  List<FoodRequest> get _filteredRequests {
    final source = widget.initialRequests ?? dummyFoodRequests;
    final normalizedQuery = _query.trim().toLowerCase();

    final filtered = source.where((request) {
      if (_mineOnly && widget.currentUserId != null) {
        if (request.owner.id != widget.currentUserId) return false;
      }
      if (_selectedStatus != null &&
          request.effectiveStatus != _selectedStatus) {
        return false;
      }
      if (normalizedQuery.isNotEmpty) {
        final matchesTitle =
            request.title.toLowerCase().contains(normalizedQuery);
        final matchesFood =
            request.foodItem.toLowerCase().contains(normalizedQuery);
        final matchesLocation =
            request.location.toLowerCase().contains(normalizedQuery);
        if (!matchesTitle && !matchesFood && !matchesLocation) {
          return false;
        }
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      if (_selectedSort == 'oldest') {
        return a.createdAt.compareTo(b.createdAt);
      }
      return b.createdAt.compareTo(a.createdAt);
    });

    return filtered;
  }

  bool get _hasActiveFilter =>
      _query.trim().isNotEmpty || _selectedStatus != null || _mineOnly;

  void _resetFilters() {
    setState(() {
      _query = '';
      _selectedStatus = null;
      _mineOnly = false;
      _selectedSort = 'newest';
    });
  }

  void _showComingSoon(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filtered = _filteredRequests;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.inversePrimary,
        title: const Text('Food Rescue Request Board'),
      ),
      drawer: const LeftDrawer(),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Buat Permintaan Baru',
        onPressed: () =>
            _showComingSoon('Form buat permintaan akan tersedia di Tahap 3.'),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: RequestFilterBar(
              initialQuery: _query,
              selectedStatus: _selectedStatus,
              mineOnly: _mineOnly,
              isAuthenticated: widget.currentUserId != null,
              selectedSort: _selectedSort,
              onSearchChanged: (value) {
                setState(() => _query = value);
              },
              onStatusChanged: (status) {
                setState(() => _selectedStatus = status);
              },
              onMineChanged: (mine) {
                setState(() => _mineOnly = mine);
              },
              onSortChanged: (sort) {
                setState(() => _selectedSort = sort);
              },
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildBodyState(context, filtered),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyState(BuildContext context, List<FoodRequest> requests) {
    if (_isLoading) {
      return const Center(
        key: ValueKey('loading'),
        child: CircularProgressIndicator(),
      );
    }

    if (requests.isEmpty) {
      return _EmptyBoardState(
        key: const ValueKey('empty'),
        hasActiveFilter: _hasActiveFilter,
        onResetFilters: _resetFilters,
      );
    }

    return LayoutBuilder(
      key: const ValueKey('list'),
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: RequestCard(
                  request: request,
                  onTap: () => _showComingSoon(
                    'Halaman detail "${request.title}" akan tersedia di Tahap 3.',
                  ),
                ),
              );
            },
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
          itemCount: requests.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 240,
          ),
          itemBuilder: (context, index) {
            final request = requests[index];
            return RequestCard(
              request: request,
              onTap: () => _showComingSoon(
                'Halaman detail "${request.title}" akan tersedia di Tahap 3.',
              ),
            );
          },
        );
      },
    );
  }
}

class _EmptyBoardState extends StatelessWidget {
  final bool hasActiveFilter;
  final VoidCallback onResetFilters;

  const _EmptyBoardState({
    super.key,
    required this.hasActiveFilter,
    required this.onResetFilters,
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
    );
  }
}
