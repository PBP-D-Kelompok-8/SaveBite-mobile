/// Model generik untuk respons paginasi REST API `request_board`.
class PaginatedResponse<T> {
  final int count;
  final int page;
  final int pageSize;
  final int totalPages;
  final List<T> results;

  const PaginatedResponse({
    required this.count,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.results,
  });

  /// Mengembalikan `true` jika masih ada halaman berikutnya yang dapat dimuat.
  bool get hasNextPage => page < totalPages;

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) fromJsonT,
  ) {
    final rawResults = json['results'] as List<dynamic>? ?? const [];

    return PaginatedResponse<T>(
      count: (json['count'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? 20,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 1,
      results: rawResults
          .map((item) => fromJsonT(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
