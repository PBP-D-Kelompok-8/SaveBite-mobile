import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:savebite_mobile/request_board/models/food_request.dart';
import 'package:savebite_mobile/request_board/services/request_board_service.dart';
import 'package:savebite_mobile/request_board/services/session_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// State utama halaman daftar Request Board.
enum RequestBoardStatus {
  initial,
  loading,
  success,
  error,
  offlineCached,
}

/// Provider (`ChangeNotifier`) untuk mengelola state daftar Request Board,
/// filter/pencarian, paginasi, cache offline halaman 1 publik, serta
/// sinkronisasi perubahan sesi pengguna.
class RequestBoardProvider extends ChangeNotifier {
  static const String publicPage1CacheKey =
      'request_board_public_page1_cache_v1';
  static const String publicPage1CachedAtKey =
      'request_board_public_page1_cached_at_v1';

  final RequestBoardService service;
  final Future<SharedPreferences> Function() _prefsProvider;

  RequestBoardStatus _boardStatus = RequestBoardStatus.initial;
  List<FoodRequest> _requests = [];
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  bool _isLoadingMore = false;
  String? _errorMessage;
  bool _isForbiddenError = false;
  DateTime? _cachedAt;

  String _query = '';
  String? _selectedStatus;
  bool _mineOnly = false;
  String _selectedSort = 'newest';

  int _requestGeneration = 0;
  bool _disposed = false;
  late bool _lastKnownAuthenticated;
  late int? _lastKnownUserId;

  RequestBoardProvider({
    required this.service,
    Future<SharedPreferences> Function()? prefsProvider,
  }) : _prefsProvider = prefsProvider ?? SharedPreferences.getInstance {
    _lastKnownAuthenticated = service.sessionClient.isAuthenticated;
    _lastKnownUserId = service.sessionClient.currentUserId;
    service.sessionClient.addListener(_handleSessionChanged);
  }

  RequestBoardStatus get boardStatus => _boardStatus;
  List<FoodRequest> get requests => List.unmodifiable(_requests);
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalCount => _totalCount;
  bool get isLoading => _boardStatus == RequestBoardStatus.loading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isOfflineCached =>
      _boardStatus == RequestBoardStatus.offlineCached;
  bool get hasError => _boardStatus == RequestBoardStatus.error;
  String? get errorMessage => _errorMessage;
  bool get isForbiddenError => _isForbiddenError;
  DateTime? get cachedAt => _cachedAt;
  bool get hasNextPage => _currentPage < _totalPages;

  String get query => _query;
  String? get selectedStatus => _selectedStatus;
  bool get mineOnly => _mineOnly;
  String get selectedSort => _selectedSort;
  bool get hasActiveFilter =>
      _query.trim().isNotEmpty || _selectedStatus != null || _mineOnly;

  SaveBiteSessionClient get sessionClient => service.sessionClient;
  int? get currentUserId => service.sessionClient.currentUserId;
  bool get isAuthenticated =>
      service.sessionClient.isAuthenticated ||
      service.sessionClient.currentUserId != null;

  void _handleSessionChanged() {
    if (_disposed) return;
    final nowAuth = isAuthenticated;
    final nowUserId = currentUserId;

    if (nowAuth == _lastKnownAuthenticated && nowUserId == _lastKnownUserId) {
      return;
    }

    _lastKnownAuthenticated = nowAuth;
    _lastKnownUserId = nowUserId;

    if (!nowAuth && _mineOnly) {
      _mineOnly = false;
    }

    // Batalkan efek respons lama dan segarkan board sesuai akun/tamu baru.
    _requestGeneration++;
    loadRequests(showLoading: true);
  }

  /// Memuat ulang daftar dari halaman 1 dengan parameter filter aktif saat ini.
  Future<void> loadRequests({bool showLoading = true}) async {
    final generation = ++_requestGeneration;
    _isLoadingMore = false;
    _errorMessage = null;
    _isForbiddenError = false;

    if (showLoading) {
      _boardStatus = RequestBoardStatus.loading;
      _notify();
    }

    try {
      final response = await service.fetchRequests(
        page: 1,
        query: _query,
        status: _selectedStatus,
        mine: _mineOnly,
        sort: _selectedSort,
      );

      if (_disposed || generation != _requestGeneration) return;

      _requests = List<FoodRequest>.from(response.results);
      _currentPage = response.page;
      _totalPages = response.totalPages;
      _totalCount = response.count;
      _boardStatus = RequestBoardStatus.success;
      _cachedAt = null;
      _notify();

      // Simpan cache offline hanya untuk halaman 1 publik (`mine == false`).
      if (!_mineOnly &&
          _query.trim().isEmpty &&
          _selectedStatus == null &&
          _selectedSort == 'newest') {
        await _savePublicPage1Cache(response.results);
      }
    } on RequestBoardNetworkException catch (e) {
      if (_disposed || generation != _requestGeneration) return;

      if (!_mineOnly) {
        final cached = await _loadPublicPage1Cache();
        if (_disposed || generation != _requestGeneration) return;

        if (cached != null) {
          _requests = cached.items;
          _currentPage = 1;
          _totalPages = 1;
          _totalCount = cached.items.length;
          _cachedAt = cached.cachedAt;
          _boardStatus = RequestBoardStatus.offlineCached;
          _errorMessage = e.message;
          _notify();
          return;
        }
      }

      _boardStatus = RequestBoardStatus.error;
      _errorMessage = e.message;
      _notify();
    } on RequestBoardForbiddenException catch (e) {
      if (_disposed || generation != _requestGeneration) return;
      _boardStatus = RequestBoardStatus.error;
      _isForbiddenError = true;
      _errorMessage = e.message;
      _notify();
    } on RequestBoardApiException catch (e) {
      if (_disposed || generation != _requestGeneration) return;
      _boardStatus = RequestBoardStatus.error;
      _errorMessage = e.message;
      _notify();
    }
  }

  /// Menarik ulang data terbaru (*pull-to-refresh* / tombol "Coba Lagi").
  Future<void> refresh() => loadRequests(showLoading: _requests.isEmpty);

  /// Memuat halaman berikutnya (`page + 1`) hanya bila `currentPage < totalPages`.
  /// Jika server merespons `404` (halaman di luar rentang), daftar dimuat ulang
  /// dari halaman 1.
  Future<void> loadNextPage() async {
    if (_isLoadingMore || !hasNextPage || isLoading) return;

    final generation = _requestGeneration;
    _isLoadingMore = true;
    _errorMessage = null;
    _notify();

    try {
      final response = await service.fetchRequests(
        page: _currentPage + 1,
        query: _query,
        status: _selectedStatus,
        mine: _mineOnly,
        sort: _selectedSort,
      );

      if (_disposed || generation != _requestGeneration) return;

      _requests = [..._requests, ...response.results];
      _currentPage = response.page;
      _totalPages = response.totalPages;
      _totalCount = response.count;
      _isLoadingMore = false;
      _boardStatus = RequestBoardStatus.success;
      _notify();
    } on RequestBoardNotFoundException {
      if (_disposed || generation != _requestGeneration) return;
      _isLoadingMore = false;
      await loadRequests(showLoading: true);
    } on RequestBoardNetworkException catch (e) {
      if (_disposed || generation != _requestGeneration) return;
      _isLoadingMore = false;
      _errorMessage = e.message;
      _notify();
    } on RequestBoardForbiddenException catch (e) {
      if (_disposed || generation != _requestGeneration) return;
      _isLoadingMore = false;
      _isForbiddenError = true;
      _errorMessage = e.message;
      _notify();
    } on RequestBoardApiException catch (e) {
      if (_disposed || generation != _requestGeneration) return;
      _isLoadingMore = false;
      _errorMessage = e.message;
      _notify();
    }
  }

  Future<void> setSearchQuery(String query) {
    final trimmed = query.trim();
    final bounded =
        trimmed.length > 120 ? trimmed.substring(0, 120) : trimmed;
    if (bounded == _query) return Future.value();
    _query = bounded;
    return loadRequests(showLoading: true);
  }

  Future<void> setStatusFilter(String? status) {
    if (status == _selectedStatus) return Future.value();
    _selectedStatus = status;
    return loadRequests(showLoading: true);
  }

  Future<void> setMineOnly(bool mine) {
    if (!isAuthenticated && mine) {
      return Future.value();
    }
    if (mine == _mineOnly) return Future.value();
    _mineOnly = mine;
    return loadRequests(showLoading: true);
  }

  Future<void> setSort(String sort) {
    if (sort == _selectedSort) return Future.value();
    _selectedSort = sort;
    return loadRequests(showLoading: true);
  }

  Future<void> resetFilters() {
    _query = '';
    _selectedStatus = null;
    _mineOnly = false;
    _selectedSort = 'newest';
    return loadRequests(showLoading: true);
  }

  /// Menyisipkan atau memperbarui item lokal setelah create/detail kembali.
  void upsertRequest(FoodRequest request) {
    final idx = _requests.indexWhere((item) => item.id == request.id);
    if (idx != -1) {
      final updated = List<FoodRequest>.from(_requests);
      updated[idx] = request;
      _requests = updated;
    } else {
      _requests = [request, ..._requests];
      _totalCount++;
    }
    _notify();
  }

  /// Menghapus item lokal setelah delete berhasil di halaman detail.
  void removeRequestById(int id) {
    final before = _requests.length;
    _requests = _requests.where((item) => item.id != id).toList();
    if (_requests.length < before && _totalCount > 0) {
      _totalCount--;
    }
    _notify();
  }

  Future<void> _savePublicPage1Cache(List<FoodRequest> items) async {
    try {
      final prefs = await _prefsProvider();
      final encoded = jsonEncode(
        items.map((item) => item.toCacheJson()).toList(),
      );
      await prefs.setString(publicPage1CacheKey, encoded);
      await prefs.setString(
        publicPage1CachedAtKey,
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (_) {
      // Kegagalan penulisan cache tidak boleh menggagalkan tampilan data live.
    }
  }

  Future<_CachedBoardData?> _loadPublicPage1Cache() async {
    try {
      final prefs = await _prefsProvider();
      final raw = prefs.getString(publicPage1CacheKey);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;

      final items = decoded
          .whereType<Map<String, dynamic>>()
          .map(FoodRequest.fromJson)
          .toList();

      final rawTime = prefs.getString(publicPage1CachedAtKey);
      final cachedAt = rawTime != null ? DateTime.tryParse(rawTime) : null;
      return _CachedBoardData(items: items, cachedAt: cachedAt);
    } catch (_) {
      return null;
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    service.sessionClient.removeListener(_handleSessionChanged);
    super.dispose();
  }
}

class _CachedBoardData {
  final List<FoodRequest> items;
  final DateTime? cachedAt;

  const _CachedBoardData({
    required this.items,
    required this.cachedAt,
  });
}
