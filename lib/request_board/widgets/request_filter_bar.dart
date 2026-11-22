import 'dart:async';

import 'package:flutter/material.dart';
import 'package:savebite_mobile/request_board/models/food_request.dart';
import 'package:savebite_mobile/request_board/widgets/request_card.dart';

/// Bar pencarian dan filter untuk halaman Request Board.
///
/// Mengimplementasikan debounce 350ms pada kolom pencarian (maks. 120 karakter),
/// filter status (`filterStatusChoices`), toggle "Permintaan Saya", serta
/// dropdown urutan (`newest` / `oldest`).
class RequestFilterBar extends StatefulWidget {
  final String initialQuery;
  final String? selectedStatus;
  final bool mineOnly;
  final bool isAuthenticated;
  final String selectedSort;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<bool> onMineChanged;
  final ValueChanged<String> onSortChanged;

  const RequestFilterBar({
    super.key,
    this.initialQuery = '',
    this.selectedStatus,
    this.mineOnly = false,
    this.isAuthenticated = true,
    this.selectedSort = 'newest',
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onMineChanged,
    required this.onSortChanged,
  });

  @override
  State<RequestFilterBar> createState() => _RequestFilterBarState();
}

class _RequestFilterBarState extends State<RequestFilterBar> {
  static const int _maxQueryLength = 120;
  static const Duration _debounceDuration = Duration(milliseconds: 350);

  late final TextEditingController _searchController;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
  }

  @override
  void didUpdateWidget(covariant RequestFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialQuery != oldWidget.initialQuery &&
        widget.initialQuery != _searchController.text) {
      _searchController.text = widget.initialQuery;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchInput(String value) {
    setState(() {});
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      if (!mounted) return;
      widget.onSearchChanged(value.trim());
    });
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _searchController.clear();
    setState(() {});
    widget.onSearchChanged('');
  }

  String _sortLabel(String sort) {
    return sort == 'oldest' ? 'Terlama' : 'Terbaru';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          maxLength: _maxQueryLength,
          textInputAction: TextInputAction.search,
          onChanged: _handleSearchInput,
          decoration: InputDecoration(
            hintText: 'Cari judul, bahan makanan, atau lokasi...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    tooltip: 'Hapus pencarian',
                    icon: const Icon(Icons.close),
                    onPressed: _clearSearch,
                  )
                : null,
            counterText: '',
            isDense: true,
            filled: true,
            fillColor: colorScheme.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Semua'),
                selected: widget.selectedStatus == null,
                onSelected: (_) => widget.onStatusChanged(null),
              ),
              ...filterStatusChoices.map((status) {
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ChoiceChip(
                    label: Text(requestStatusLabel(status)),
                    selected: widget.selectedStatus == status,
                    onSelected: (selected) {
                      widget.onStatusChanged(selected ? status : null);
                    },
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            FilterChip(
              avatar: Icon(
                Icons.person_outline,
                size: 18,
                color: widget.isAuthenticated
                    ? null
                    : colorScheme.onSurface.withValues(alpha: 0.38),
              ),
              label: const Text('Permintaan Saya'),
              selected: widget.isAuthenticated && widget.mineOnly,
              onSelected: widget.isAuthenticated ? widget.onMineChanged : null,
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: DropdownButtonFormField<String>(
                initialValue: sortChoices.contains(widget.selectedSort)
                    ? widget.selectedSort
                    : sortChoices.first,
                isDense: true,
                decoration: InputDecoration(
                  labelText: 'Urutkan',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                style: textTheme.bodyMedium,
                items: sortChoices.map((sort) {
                  return DropdownMenuItem<String>(
                    value: sort,
                    child: Text(_sortLabel(sort)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    widget.onSortChanged(value);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
