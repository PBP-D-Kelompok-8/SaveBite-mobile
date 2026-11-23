import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:savebite_mobile/request_board/models/food_request.dart';
import 'package:savebite_mobile/request_board/services/request_board_service.dart';
import 'package:savebite_mobile/request_board/services/session_client.dart';

Map<String, dynamic> _sampleRequestJson({
  int id = 10,
  String status = 'pending',
  String effectiveStatus = 'pending',
  int? selectedOfferId,
}) {
  return {
    'id': id,
    'owner': {'id': 7, 'display_name': 'Dapur Menteng'},
    'title': 'Butuh 2 kg Tomat',
    'food_item': 'Tomat Merah',
    'quantity': '2.00',
    'unit': 'kg',
    'description': 'Untuk saus pasta',
    'location': 'Menteng',
    'status': status,
    'effective_status': effectiveStatus,
    'expires_at': null,
    'offer_count': 1,
    'has_offered': false,
    'selected_offer_id': selectedOfferId,
    'created_at': '2026-11-20T10:00:00Z',
    'updated_at': '2026-11-20T10:00:00Z',
  };
}

Map<String, dynamic> _sampleOfferJson({
  int id = 55,
  int requestId = 10,
  bool isSelected = false,
}) {
  return {
    'id': id,
    'request_id': requestId,
    'offered_by': {'id': 12, 'display_name': 'Budi'},
    'created_at': '2026-11-20T11:00:00Z',
    'is_selected': isSelected,
  };
}

void main() {
  group('generateUuidV4', () {
    test('produces valid RFC 4122 v4 UUIDs', () {
      final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      final first = generateUuidV4();
      final second = generateUuidV4();

      expect(uuidRegex.hasMatch(first), isTrue);
      expect(uuidRegex.hasMatch(second), isTrue);
      expect(first, isNot(equals(second)));
    });
  });

  group('SaveBiteSessionClient', () {
    test('uses default PWS baseUrl and normalizes trailing slash', () {
      final defaultClient = SaveBiteSessionClient(
        httpClient: MockClient((_) async => http.Response('', 200)),
      );
      expect(
        defaultClient.baseUrl,
        'https://reshandy-taftazani-savebite.pws.cs.ui.ac.id',
      );

      final customClient = SaveBiteSessionClient(
        baseUrl: 'http://127.0.0.1:8000/',
        httpClient: MockClient((_) async => http.Response('', 200)),
      );
      expect(customClient.baseUrl, 'http://127.0.0.1:8000');
    });

    test('login extracts CSRF token, posts form, and stores session cookies',
        () async {
      late http.Request capturedPost;

      final mockHttp = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/login/') {
          return http.Response(
            '<form><input type="hidden" name="csrfmiddlewaretoken" value="hidden-csrf-123"></form>',
            200,
            headers: {
              'set-cookie':
                  'csrftoken=cookie-csrf-456; expires=Mon, 22 Nov 2027 01:22:38 GMT; Path=/',
            },
          );
        }

        if (request.method == 'POST' && request.url.path == '/login/') {
          capturedPost = request;
          return http.Response(
            '',
            302,
            headers: {
              'location': '/',
              'set-cookie':
                  'csrftoken=rotated-csrf-789; Path=/, sessionid=sess-abc-999; HttpOnly; Path=/',
            },
          );
        }

        return http.Response('Not found', 404);
      });

      final session = SaveBiteSessionClient(
        baseUrl: 'https://example.test',
        httpClient: mockHttp,
      );

      await session.login(
        username: 'owner1',
        password: 'secret',
        userId: 7,
      );

      expect(session.isAuthenticated, isTrue);
      expect(session.sessionId, 'sess-abc-999');
      expect(session.csrfToken, 'rotated-csrf-789');
      expect(session.currentUserId, 7);
      expect(session.currentUsername, 'owner1');

      expect(capturedPost.headers['X-CSRFToken'], 'cookie-csrf-456');
      expect(
        capturedPost.bodyFields['csrfmiddlewaretoken'],
        'hidden-csrf-123',
      );
      expect(capturedPost.bodyFields['username'], 'owner1');
      expect(capturedPost.bodyFields['password'], 'secret');
    });

    test('login throws SaveBiteAuthException when credentials rejected (200)',
        () async {
      final mockHttp = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response('<form></form>', 200, headers: {
            'set-cookie': 'csrftoken=csrf-1; Path=/',
          });
        }
        return http.Response('<form>Invalid login</form>', 200);
      });

      final session = SaveBiteSessionClient(
        baseUrl: 'https://example.test',
        httpClient: mockHttp,
      );

      expect(
        () => session.login(username: 'bad', password: 'wrong'),
        throwsA(isA<SaveBiteAuthException>()),
      );
      expect(session.isAuthenticated, isFalse);
    });

    test('logout calls /logout/ with CSRF token and clears local session',
        () async {
      late http.Request capturedLogout;
      final mockHttp = MockClient((request) async {
        capturedLogout = request;
        return http.Response('', 302, headers: {'location': '/login/'});
      });

      final session = SaveBiteSessionClient(
        baseUrl: 'https://example.test',
        httpClient: mockHttp,
      );
      session.setSession(
        sessionId: 'sess-1',
        csrfToken: 'csrf-1',
        userId: 7,
        username: 'owner1',
      );

      await session.logout();

      expect(capturedLogout.method, 'POST');
      expect(capturedLogout.url.path, '/logout/');
      expect(capturedLogout.headers['X-CSRFToken'], 'csrf-1');
      expect(session.isAuthenticated, isFalse);
      expect(session.currentUserId, isNull);
      expect(session.csrfToken, isNull);
    });
  });

  group('RequestBoardService', () {
    SaveBiteSessionClient createAuthedClient(
      Future<http.Response> Function(http.Request request) handler,
    ) {
      final client = SaveBiteSessionClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient(handler),
      );
      client.setSession(
        sessionId: 'sess-xyz',
        csrfToken: 'csrf-xyz',
        userId: 7,
        username: 'owner1',
      );
      return client;
    }

    test('fetchRequests sends filter query params and parses pagination',
        () async {
      late Uri capturedUri;
      final service = RequestBoardService(
        sessionClient: createAuthedClient((request) async {
          capturedUri = request.url;
          return http.Response(
            jsonEncode({
              'count': 21,
              'page': 1,
              'page_size': 20,
              'total_pages': 2,
              'results': [_sampleRequestJson()],
            }),
            200,
          );
        }),
      );

      final longQuery = 'a' * 150;
      final result = await service.fetchRequests(
        page: 1,
        query: longQuery,
        status: 'offered',
        mine: true,
        sort: 'oldest',
      );

      expect(capturedUri.path, '/api/v1/requests/');
      expect(capturedUri.queryParameters['page'], '1');
      expect(capturedUri.queryParameters['q']!.length, 120);
      expect(capturedUri.queryParameters['status'], 'offered');
      expect(capturedUri.queryParameters['mine'], 'true');
      expect(capturedUri.queryParameters['sort'], 'oldest');

      expect(result.count, 21);
      expect(result.hasNextPage, isTrue);
      expect(result.results.single.id, 10);
    });

    test('fetchRequestDetail fetches and parses single FoodRequest', () async {
      late Uri capturedUri;
      final service = RequestBoardService(
        sessionClient: createAuthedClient((request) async {
          capturedUri = request.url;
          return http.Response(jsonEncode(_sampleRequestJson(id: 42)), 200);
        }),
      );

      final detail = await service.fetchRequestDetail(42);

      expect(capturedUri.path, '/api/v1/requests/42/');
      expect(detail.id, 42);
    });

    test(
        'createRequest sends Idempotency-Key, CSRF, strict payload, and accepts 201/200',
        () async {
      late http.Request capturedRequest;
      var statusToReturn = 201;

      final service = RequestBoardService(
        sessionClient: createAuthedClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode(_sampleRequestJson(id: 99)),
            statusToReturn,
          );
        }),
      );

      const payload = FoodRequestCreatePayload(
        title: 'Butuh Tomat',
        foodItem: 'Tomat',
        quantity: '2.50',
        unit: 'kg',
      );
      const key = '123e4567-e89b-42d3-a456-426614174000';

      final created = await service.createRequest(
        payload,
        idempotencyKey: key,
      );
      expect(created.id, 99);
      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.url.path, '/api/v1/requests/');
      expect(capturedRequest.headers['Idempotency-Key'], key);
      expect(capturedRequest.headers['X-CSRFToken'], 'csrf-xyz');
      expect(capturedRequest.headers['Cookie'], contains('sessionid=sess-xyz'));

      final decodedBody =
          jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      expect(decodedBody.containsKey('expires_at'), isFalse);
      expect(decodedBody['quantity'], '2.50');

      statusToReturn = 200;
      final replayed = await service.createRequest(
        payload,
        idempotencyKey: key,
      );
      expect(replayed.id, 99);
    });

    test('fetchRequestCreationStatus returns status on 200 and null on 404',
        () async {
      var return404 = false;
      final service = RequestBoardService(
        sessionClient: createAuthedClient((request) async {
          expect(
            request.url.path,
            '/api/v1/request-creations/123e4567-e89b-42d3-a456-426614174000/',
          );
          if (return404) {
            return http.Response(jsonEncode({'detail': 'Not found.'}), 404);
          }
          return http.Response(
            jsonEncode({'state': 'created', 'request_id': 99}),
            200,
          );
        }),
      );

      final created = await service.fetchRequestCreationStatus(
        '123e4567-e89b-42d3-a456-426614174000',
      );
      expect(created, isNotNull);
      expect(created!.isCreated, isTrue);
      expect(created.requestId, 99);

      return404 = true;
      final missing = await service.fetchRequestCreationStatus(
        '123e4567-e89b-42d3-a456-426614174000',
      );
      expect(missing, isNull);
    });

    test('deleteRequest sends empty body and expects 204', () async {
      late http.Request capturedRequest;
      final service = RequestBoardService(
        sessionClient: createAuthedClient((request) async {
          capturedRequest = request;
          return http.Response('', 204);
        }),
      );

      await service.deleteRequest(10);

      expect(capturedRequest.method, 'DELETE');
      expect(capturedRequest.url.path, '/api/v1/requests/10/');
      expect(capturedRequest.body, isEmpty);
      expect(capturedRequest.headers['X-CSRFToken'], 'csrf-xyz');
    });

    test('fetchOffers sends page parameter and parses RequestOffer list',
        () async {
      late Uri capturedUri;
      final service = RequestBoardService(
        sessionClient: createAuthedClient((request) async {
          capturedUri = request.url;
          return http.Response(
            jsonEncode({
              'count': 1,
              'page': 2,
              'page_size': 20,
              'total_pages': 2,
              'results': [_sampleOfferJson()],
            }),
            200,
          );
        }),
      );

      final offers = await service.fetchOffers(10, page: 2);

      expect(capturedUri.path, '/api/v1/requests/10/offers/');
      expect(capturedUri.queryParameters['page'], '2');
      expect(offers.hasNextPage, isFalse);
      expect(offers.results.single.id, 55);
    });

    test('submitOffer sends {} body and accepts 201 and 200 replay', () async {
      late http.Request capturedRequest;
      var code = 201;
      final service = RequestBoardService(
        sessionClient: createAuthedClient((request) async {
          capturedRequest = request;
          return http.Response(jsonEncode(_sampleOfferJson()), code);
        }),
      );

      final offer1 = await service.submitOffer(10);
      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.url.path, '/api/v1/requests/10/offers/');
      expect(capturedRequest.body, '{}');
      expect(offer1.id, 55);

      code = 200;
      final offer2 = await service.submitOffer(10);
      expect(offer2.id, 55);
    });

    test('selectOffer sends PATCH with offer_id and returns updated FoodRequest',
        () async {
      late http.Request capturedRequest;
      final service = RequestBoardService(
        sessionClient: createAuthedClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode(
              _sampleRequestJson(status: 'offered', selectedOfferId: 55),
            ),
            200,
          );
        }),
      );

      final updated = await service.selectOffer(10, 55);

      expect(capturedRequest.method, 'PATCH');
      expect(capturedRequest.url.path, '/api/v1/requests/10/selection/');
      expect(jsonDecode(capturedRequest.body), {'offer_id': 55});
      expect(updated.selectedOfferId, 55);
    });

    test('fulfillRequest sends PATCH with status fulfilled', () async {
      late http.Request capturedRequest;
      final service = RequestBoardService(
        sessionClient: createAuthedClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode(
              _sampleRequestJson(
                status: 'fulfilled',
                effectiveStatus: 'fulfilled',
                selectedOfferId: 55,
              ),
            ),
            200,
          );
        }),
      );

      final updated = await service.fulfillRequest(10);

      expect(capturedRequest.method, 'PATCH');
      expect(capturedRequest.url.path, '/api/v1/requests/10/status/');
      expect(jsonDecode(capturedRequest.body), {'status': 'fulfilled'});
      expect(updated.effectiveStatus, 'fulfilled');
    });

    test('maps 400, 403, 404, 409, and timeout to typed exceptions', () async {
      var nextStatus = 400;
      var nextBody = jsonEncode({
        'quantity': ['Jumlah harus lebih besar dari 0.'],
        'expires_at': ['Tenggat harus di masa depan.'],
      });
      var throwTimeout = false;

      final service = RequestBoardService(
        sessionClient: createAuthedClient((request) async {
          if (throwTimeout) {
            throw TimeoutException('Request timed out');
          }
          return http.Response(nextBody, nextStatus);
        }),
      );

      await expectLater(
        service.fetchRequestDetail(10),
        throwsA(
          isA<RequestBoardValidationException>().having(
            (e) => e.fieldErrors,
            'fieldErrors',
            {
              'quantity': 'Jumlah harus lebih besar dari 0.',
              'expires_at': 'Tenggat harus di masa depan.',
            },
          ),
        ),
      );

      nextStatus = 403;
      nextBody = jsonEncode({'detail': 'Authentication credentials were not provided.'});
      await expectLater(
        service.submitOffer(10),
        throwsA(isA<RequestBoardForbiddenException>()),
      );

      nextStatus = 404;
      nextBody = jsonEncode({'detail': 'Not found.'});
      await expectLater(
        service.fetchRequestDetail(999),
        throwsA(isA<RequestBoardNotFoundException>()),
      );

      nextStatus = 409;
      nextBody = jsonEncode({
        'detail': 'Penawaran sudah ditutup.',
        'code': 'offers_closed',
      });
      await expectLater(
        service.submitOffer(10),
        throwsA(
          isA<RequestBoardConflictException>()
              .having((e) => e.code, 'code', 'offers_closed'),
        ),
      );

      throwTimeout = true;
      await expectLater(
        service.fetchRequests(),
        throwsA(isA<RequestBoardNetworkException>()),
      );
    });
  });
}
