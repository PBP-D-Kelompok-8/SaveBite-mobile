import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:savebite_mobile/request_board/providers/request_board_provider.dart';
import 'package:savebite_mobile/request_board/services/request_board_service.dart';
import 'package:savebite_mobile/request_board/services/session_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _requestJson(int id, String title, {int ownerId = 1}) {
  return {
    'id': id,
    'owner': {'id': ownerId, 'display_name': 'User $ownerId'},
    'title': title,
    'food_item': 'Bahan $id',
    'quantity': '1.00',
    'unit': 'kg',
    'description': '',
    'location': 'Depok',
    'status': 'pending',
    'effective_status': 'pending',
    'expires_at': null,
    'offer_count': 0,
    'has_offered': false,
    'selected_offer_id': null,
    'created_at': '2026-11-20T10:00:00Z',
    'updated_at': '2026-11-20T10:00:00Z',
  };
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('caches public page 1 and falls back to offlineCached on network error',
      () async {
    var shouldFail = false;

    final sessionClient = SaveBiteSessionClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        if (shouldFail) {
          throw http.ClientException('No internet');
        }
        return http.Response(
          jsonEncode({
            'count': 1,
            'page': 1,
            'page_size': 20,
            'total_pages': 1,
            'results': [_requestJson(101, 'Publik Halaman 1')],
          }),
          200,
        );
      }),
    );

    final provider = RequestBoardProvider(
      service: RequestBoardService(sessionClient: sessionClient),
    );

    await provider.loadRequests();
    expect(provider.boardStatus, RequestBoardStatus.success);
    expect(provider.requests.single.title, 'Publik Halaman 1');

    // Sekarang simulasi offline.
    shouldFail = true;
    await provider.refresh();

    expect(provider.boardStatus, RequestBoardStatus.offlineCached);
    expect(provider.isOfflineCached, isTrue);
    expect(provider.requests.single.title, 'Publik Halaman 1');
  });

  test('never caches or falls back to public cache when mine=true', () async {
    var shouldFail = false;

    final sessionClient = SaveBiteSessionClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        if (shouldFail) {
          throw http.ClientException('No internet');
        }
        return http.Response(
          jsonEncode({
            'count': 1,
            'page': 1,
            'page_size': 20,
            'total_pages': 1,
            'results': [_requestJson(202, 'Privat Milik Saya', ownerId: 9)],
          }),
          200,
        );
      }),
    );
    sessionClient.setSession(
      sessionId: 'sess-9',
      csrfToken: 'csrf-9',
      userId: 9,
      username: 'user9',
    );

    final provider = RequestBoardProvider(
      service: RequestBoardService(sessionClient: sessionClient),
    );

    await provider.setMineOnly(true);
    expect(provider.boardStatus, RequestBoardStatus.success);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(RequestBoardProvider.publicPage1CacheKey), isNull);

    shouldFail = true;
    await provider.refresh();
    expect(provider.boardStatus, RequestBoardStatus.error);
    expect(provider.isOfflineCached, isFalse);
  });

  test('ignores stale search response when newer filter arrives first',
      () async {
    final firstCompleter = Completer<http.Response>();

    final sessionClient = SaveBiteSessionClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        final q = request.url.queryParameters['q'] ?? '';
        if (q == 'lama') {
          return firstCompleter.future;
        }
        return http.Response(
          jsonEncode({
            'count': 1,
            'page': 1,
            'page_size': 20,
            'total_pages': 1,
            'results': [_requestJson(2, 'Hasil Baru')],
          }),
          200,
        );
      }),
    );

    final provider = RequestBoardProvider(
      service: RequestBoardService(sessionClient: sessionClient),
    );

    final slowFuture = provider.setSearchQuery('lama');
    await provider.setSearchQuery('baru');

    expect(provider.requests.single.title, 'Hasil Baru');

    // Respons lama tiba belakangan -> harus diabaikan.
    firstCompleter.complete(
      http.Response(
        jsonEncode({
          'count': 1,
          'page': 1,
          'page_size': 20,
          'total_pages': 1,
          'results': [_requestJson(1, 'Hasil Lama')],
        }),
        200,
      ),
    );
    await slowFuture;

    expect(provider.requests.single.title, 'Hasil Baru');
  });

  test('pagination loads page 2 and recovers from 404 by reloading page 1',
      () async {
    var return404OnPage2 = false;

    final sessionClient = SaveBiteSessionClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        final page = request.url.queryParameters['page'] ?? '1';
        if (page == '2') {
          if (return404OnPage2) {
            return http.Response(jsonEncode({'detail': 'Invalid page.'}), 404);
          }
          return http.Response(
            jsonEncode({
              'count': 21,
              'page': 2,
              'page_size': 20,
              'total_pages': 2,
              'results': [_requestJson(21, 'Item Halaman 2')],
            }),
            200,
          );
        }

        return http.Response(
          jsonEncode({
            'count': 21,
            'page': 1,
            'page_size': 20,
            'total_pages': 2,
            'results': [_requestJson(1, 'Item Halaman 1')],
          }),
          200,
        );
      }),
    );

    final provider = RequestBoardProvider(
      service: RequestBoardService(sessionClient: sessionClient),
    );

    await provider.loadRequests();
    expect(provider.hasNextPage, isTrue);

    await provider.loadNextPage();
    expect(provider.requests.length, 2);
    expect(provider.hasNextPage, isFalse);

    // Uji skenario 404 saat memuat halaman 2 -> otomatis reload halaman 1.
    return404OnPage2 = true;
    await provider.loadRequests();
    await provider.loadNextPage();

    expect(provider.currentPage, 1);
    expect(provider.requests.single.title, 'Item Halaman 1');
  });

  test('logout resets mineOnly and refreshes board', () async {
    final requestedMineFlags = <String?>[];

    final sessionClient = SaveBiteSessionClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        if (request.url.path == '/logout/') {
          return http.Response('', 302);
        }
        requestedMineFlags.add(request.url.queryParameters['mine']);
        return http.Response(
          jsonEncode({
            'count': 1,
            'page': 1,
            'page_size': 20,
            'total_pages': 1,
            'results': [_requestJson(1, 'Item')],
          }),
          200,
        );
      }),
    );
    sessionClient.setSession(
      sessionId: 'sess-1',
      csrfToken: 'csrf-1',
      userId: 1,
      username: 'user1',
    );

    final provider = RequestBoardProvider(
      service: RequestBoardService(sessionClient: sessionClient),
    );

    await provider.setMineOnly(true);
    expect(provider.mineOnly, isTrue);
    expect(requestedMineFlags.last, 'true');

    await sessionClient.logout();
    // Beri kesempatan listener memicu loadRequests.
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(provider.mineOnly, isFalse);
    expect(requestedMineFlags.last, isNull);
  });

  test('403 Forbidden sets isForbiddenError', () async {
    final sessionClient = SaveBiteSessionClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((_) async {
        return http.Response(jsonEncode({'detail': 'Forbidden'}), 403);
      }),
    );

    final provider = RequestBoardProvider(
      service: RequestBoardService(sessionClient: sessionClient),
    );

    await provider.loadRequests();
    expect(provider.boardStatus, RequestBoardStatus.error);
    expect(provider.isForbiddenError, isTrue);
  });
}
