import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:savebite_mobile/request_board/models/food_request.dart';
import 'package:savebite_mobile/request_board/providers/request_board_provider.dart';
import 'package:savebite_mobile/request_board/screens/request_board_page.dart';
import 'package:savebite_mobile/request_board/screens/request_detail_page.dart';
import 'package:savebite_mobile/request_board/screens/request_form_page.dart';
import 'package:savebite_mobile/request_board/services/idempotency_draft_store.dart';
import 'package:savebite_mobile/request_board/services/request_board_service.dart';
import 'package:savebite_mobile/request_board/services/session_client.dart';
import 'package:savebite_mobile/request_board/widgets/offer_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _reqJson({
  int id = 1,
  int ownerId = 1,
  String title = 'Butuh Beras',
  String status = 'offered',
  String effectiveStatus = 'offered',
  int? selectedOfferId,
  int offerCount = 2,
  bool hasOffered = false,
}) {
  return {
    'id': id,
    'owner': {'id': ownerId, 'display_name': 'Owner $ownerId'},
    'title': title,
    'food_item': 'Beras',
    'quantity': '2.00',
    'unit': 'kg',
    'description': 'Deskripsi permintaan',
    'location': 'Depok',
    'status': status,
    'effective_status': effectiveStatus,
    'expires_at': null,
    'offer_count': offerCount,
    'has_offered': hasOffered,
    'selected_offer_id': selectedOfferId,
    'created_at': '2026-11-20T10:00:00Z',
    'updated_at': '2026-11-20T10:00:00Z',
  };
}

Map<String, dynamic> _offerJson({
  required int id,
  required int requestId,
  required int userId,
  required String name,
  bool isSelected = false,
}) {
  return {
    'id': id,
    'request_id': requestId,
    'offered_by': {'id': userId, 'display_name': name},
    'created_at': '2026-11-20T11:00:00Z',
    'is_selected': isSelected,
  };
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      '1. Owner opens offers -> logout while fetchOffers in-flight -> stale response ignored and guest view stays empty',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final offersCompleter = Completer<http.Response>();

    final sessionClient = SaveBiteSessionClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        if (request.url.path == '/logout/') {
          return http.Response('', 302);
        }
        if (request.url.path == '/api/v1/requests/1/offers/') {
          return offersCompleter.future;
        }
        if (request.url.path == '/api/v1/requests/1/') {
          return http.Response(jsonEncode(_reqJson(id: 1, ownerId: 1)), 200);
        }
        return http.Response('{}', 404);
      }),
    );
    sessionClient.setSession(
      sessionId: 'sess-owner',
      csrfToken: 'csrf-owner',
      userId: 1,
      username: 'Owner 1',
    );
    final service = RequestBoardService(sessionClient: sessionClient);
    final initialRequest = FoodRequest.fromJson(_reqJson(id: 1, ownerId: 1));

    await tester.pumpWidget(
      MaterialApp(
        home: RequestDetailPage(
          request: initialRequest,
          currentUserId: null,
          service: service,
        ),
      ),
    );
    await tester.pump();

    // Logout saat fetchOffers masih in-flight.
    await sessionClient.logout();
    await tester.pump();

    // Sekarang respons fetchOffers lama tiba -> harus diabaikan.
    offersCompleter.complete(
      http.Response(
        jsonEncode({
          'count': 1,
          'page': 1,
          'page_size': 20,
          'total_pages': 1,
          'results': [
            _offerJson(id: 101, requestId: 1, userId: 2, name: 'Penawar Rahasia'),
          ],
        }),
        200,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OfferCard), findsNothing);
    expect(find.text('Penawar Rahasia'), findsNothing);
    expect(find.text('Mode Tamu'), findsOneWidget);
  });

  testWidgets(
      '2. Stale search/filter response arriving after newer filter does not overwrite latest results',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final slowFilterCompleter = Completer<http.Response>();

    final sessionClient = SaveBiteSessionClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        final q = request.url.queryParameters['q'] ?? '';
        if (q == 'lama') {
          return slowFilterCompleter.future;
        }
        if (q == 'baru') {
          return http.Response(
            jsonEncode({
              'count': 1,
              'page': 1,
              'page_size': 20,
              'total_pages': 1,
              'results': [_reqJson(id: 2, title: 'Hasil Filter Terbaru')],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'count': 1,
            'page': 1,
            'page_size': 20,
            'total_pages': 1,
            'results': [_reqJson(id: 1, title: 'Daftar Awal')],
          }),
          200,
        );
      }),
    );

    final provider = RequestBoardProvider(
      service: RequestBoardService(sessionClient: sessionClient),
    );

    await tester.pumpWidget(
      MaterialApp(home: RequestBoardPage(provider: provider)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Daftar Awal'), findsOneWidget);

    // Filter 1 (lambat) lalu langsung Filter 2 (cepat).
    final slowFuture = provider.setSearchQuery('lama');
    await provider.setSearchQuery('baru');
    await tester.pumpAndSettle();

    expect(find.text('Hasil Filter Terbaru'), findsOneWidget);

    // Respons Filter 1 tiba belakangan -> tidak boleh menimpa Filter 2.
    slowFilterCompleter.complete(
      http.Response(
        jsonEncode({
          'count': 1,
          'page': 1,
          'page_size': 20,
          'total_pages': 1,
          'results': [_reqJson(id: 99, title: 'Hasil Filter Usang')],
        }),
        200,
      ),
    );
    await slowFuture;
    await tester.pumpAndSettle();

    expect(find.text('Hasil Filter Terbaru'), findsOneWidget);
    expect(find.text('Hasil Filter Usang'), findsNothing);
  });

  testWidgets(
      '3. Owner selects offer A on page 1, loads page 2, switches to offer B -> only B marked selected',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    int? serverSelectedOfferId;

    final sessionClient = SaveBiteSessionClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/v1/requests/1/') {
          return http.Response(
            jsonEncode(
              _reqJson(
                id: 1,
                ownerId: 1,
                selectedOfferId: serverSelectedOfferId,
              ),
            ),
            200,
          );
        }
        if (request.url.path == '/api/v1/requests/1/offers/') {
          final page = request.url.queryParameters['page'] ?? '1';
          if (page == '1') {
            return http.Response(
              jsonEncode({
                'count': 2,
                'page': 1,
                'page_size': 20,
                'total_pages': 2,
                'results': [
                  _offerJson(
                    id: 101,
                    requestId: 1,
                    userId: 2,
                    name: 'Penawar A',
                    isSelected: serverSelectedOfferId == 101,
                  ),
                ],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'count': 2,
              'page': 2,
              'page_size': 20,
              'total_pages': 2,
              'results': [
                _offerJson(
                  id: 202,
                  requestId: 1,
                  userId: 3,
                  name: 'Penawar B',
                  isSelected: serverSelectedOfferId == 202,
                ),
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/requests/1/selection/' &&
            request.method == 'PATCH') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          serverSelectedOfferId = (body['offer_id'] as num).toInt();
          return http.Response(
            jsonEncode(
              _reqJson(
                id: 1,
                ownerId: 1,
                selectedOfferId: serverSelectedOfferId,
              ),
            ),
            200,
          );
        }
        return http.Response('{}', 404);
      }),
    );
    sessionClient.setSession(
      sessionId: 'sess-owner',
      csrfToken: 'csrf-owner',
      userId: 1,
      username: 'Owner 1',
    );
    final service = RequestBoardService(sessionClient: sessionClient);

    await tester.pumpWidget(
      MaterialApp(
        home: RequestDetailPage(
          request: FoodRequest.fromJson(_reqJson(id: 1, ownerId: 1)),
          currentUserId: 1,
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Pilih Penawar A di halaman 1.
    final selectAButton = find.text('Pilih Offer');
    await tester.ensureVisible(selectAButton);
    await tester.tap(selectAButton);
    await tester.pumpAndSettle();

    expect(find.text('Terpilih'), findsOneWidget);

    // Muat halaman 2 untuk melihat Penawar B.
    final nextPageBtn = find.text('Muat Penawar Berikutnya');
    await tester.ensureVisible(nextPageBtn);
    await tester.tap(nextPageBtn);
    await tester.pumpAndSettle();

    expect(find.text('Penawar B'), findsOneWidget);

    // Ganti ke Penawar B -> hanya B yang bertanda "Terpilih".
    final switchToB = find.text('Ganti ke Penawar Ini');
    await tester.ensureVisible(switchToB);
    await tester.tap(switchToB);
    await tester.pumpAndSettle();

    expect(find.text('Terpilih'), findsOneWidget);
    final offerCards = tester.widgetList<OfferCard>(find.byType(OfferCard)).toList();
    expect(offerCards.length, 2);
    expect(offerCards[0].isSelected, isFalse); // Penawar A tidak lagi terpilih
    expect(offerCards[1].isSelected, isTrue); // Penawar B terpilih
  });

  testWidgets(
      '4. Offline fallback displays cached public page 1 and banner without leaking mine=true data',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var failNetwork = false;

    final sessionClient = SaveBiteSessionClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        if (failNetwork) {
          throw http.ClientException('Network down');
        }
        final mine = request.url.queryParameters['mine'] == 'true';
        return http.Response(
          jsonEncode({
            'count': 1,
            'page': 1,
            'page_size': 20,
            'total_pages': 1,
            'results': [
              _reqJson(
                id: mine ? 999 : 10,
                title: mine ? 'Data Privat Mine' : 'Data Publik Tersimpan',
              ),
            ],
          }),
          200,
        );
      }),
    );
    sessionClient.setSession(
      sessionId: 'sess-1',
      csrfToken: 'csrf-1',
      userId: 1,
      username: 'User 1',
    );
    final provider = RequestBoardProvider(
      service: RequestBoardService(sessionClient: sessionClient),
    );

    await tester.pumpWidget(
      MaterialApp(home: RequestBoardPage(provider: provider)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Data Publik Tersimpan'), findsOneWidget);

    // Aktifkan filter "Permintaan Saya" (mine=true) -> tidak boleh menimpa cache publik.
    await tester.tap(find.widgetWithText(FilterChip, 'Permintaan Saya'));
    await tester.pumpAndSettle();
    expect(find.text('Data Privat Mine'), findsOneWidget);

    // Matikan jaringan lalu kembali ke publik (mine=false) -> tampilkan cache publik + banner.
    failNetwork = true;
    await tester.tap(find.widgetWithText(FilterChip, 'Permintaan Saya'));
    await tester.pumpAndSettle();

    expect(
      find.text('Mode Offline — menampilkan data terakhir tersimpan'),
      findsOneWidget,
    );
    expect(find.text('Coba Lagi'), findsOneWidget);
    expect(find.text('Data Publik Tersimpan'), findsOneWidget);
    expect(find.text('Data Privat Mine'), findsNothing);
  });

  testWidgets(
      '5. RequestFormPage idempotency preserves UUID and first payload across timeout + 404 lookup until created',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 950);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final capturedKeys = <String>[];
    final capturedTitles = <String>[];
    var attempt = 0;

    final sessionClient = SaveBiteSessionClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/v1/requests/') {
          attempt++;
          capturedKeys.add(request.headers['Idempotency-Key']!);
          final decoded = jsonDecode(request.body) as Map<String, dynamic>;
          capturedTitles.add(decoded['title'] as String);

          if (attempt == 1) {
            throw TimeoutException('Timeout');
          }
          return http.Response(
            jsonEncode(_reqJson(id: 77, title: decoded['title'] as String)),
            200, // replay
          );
        }

        if (request.method == 'GET' &&
            request.url.path.startsWith('/api/v1/request-creations/')) {
          return http.Response(jsonEncode({'detail': 'Not found.'}), 404);
        }

        return http.Response('{}', 404);
      }),
    );
    sessionClient.setSession(
      sessionId: 'sess-1',
      csrfToken: 'csrf-1',
      userId: 1,
      username: 'User 1',
    );
    final service = RequestBoardService(sessionClient: sessionClient);
    var generatedCount = 0;

    FoodRequest? poppedResult;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                poppedResult = await Navigator.of(context).push<FoodRequest>(
                  MaterialPageRoute(
                    builder: (_) => RequestFormPage(
                      currentUserId: 1,
                      service: service,
                      draftStore: PendingRequestDraftStore(),
                      idempotencyKeyGenerator: () {
                        generatedCount++;
                        return '11111111-1111-4111-8111-11111111111$generatedCount';
                      },
                    ),
                  ),
                );
              },
              child: const Text('Buka Form'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka Form'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Judul Permintaan *'),
      'Judul Pertama',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nama Bahan Makanan *'),
      'Beras',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Jumlah *'),
      '2',
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('kg').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lanjut').first);
    await tester.pumpAndSettle();

    final submitBtn = find.text('Kirim Permintaan');
    await tester.ensureVisible(submitBtn);
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    // Percobaan 1 timeout + lookup 404 -> tampilkan pesan retry.
    expect(find.textContaining('Hasil pengiriman belum pasti'), findsOneWidget);

    // Kembali ke langkah 1 dan ubah judul menjadi "Judul Kedua", lalu retry.
    await tester.tap(find.text('Kembali').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Judul Permintaan *'),
      'Judul Kedua',
    );
    await tester.tap(find.text('Lanjut').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(submitBtn);
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    // Harus memakai UUID dan payload PERTAMA ("Judul Pertama").
    expect(capturedKeys, [
      '11111111-1111-4111-8111-111111111111',
      '11111111-1111-4111-8111-111111111111',
    ]);
    expect(capturedTitles, ['Judul Pertama', 'Judul Pertama']);
    expect(poppedResult?.id, 77);
  });

  testWidgets(
      '6. Ambiguous 404 on selectOffer checks parent detail once and refreshes offers when parent exists',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var detailGetCount = 0;
    var offerListRefreshCount = 0;

    final sessionClient = SaveBiteSessionClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/v1/requests/1/') {
          detailGetCount++;
          return http.Response(jsonEncode(_reqJson(id: 1, ownerId: 1)), 200);
        }
        if (request.url.path == '/api/v1/requests/1/offers/') {
          offerListRefreshCount++;
          return http.Response(
            jsonEncode({
              'count': 1,
              'page': 1,
              'page_size': 20,
              'total_pages': 1,
              'results': [
                _offerJson(id: 101, requestId: 1, userId: 2, name: 'Penawar A'),
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/requests/1/selection/' &&
            request.method == 'PATCH') {
          return http.Response(jsonEncode({'detail': 'Not found.'}), 404);
        }
        return http.Response('{}', 404);
      }),
    );
    sessionClient.setSession(
      sessionId: 'sess-owner',
      csrfToken: 'csrf-owner',
      userId: 1,
      username: 'Owner 1',
    );
    final service = RequestBoardService(sessionClient: sessionClient);

    await tester.pumpWidget(
      MaterialApp(
        home: RequestDetailPage(
          request: FoodRequest.fromJson(_reqJson(id: 1, ownerId: 1)),
          currentUserId: 1,
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final detailCallsBefore = detailGetCount;
    final offerCallsBefore = offerListRefreshCount;

    final selectBtn = find.text('Pilih Offer');
    await tester.ensureVisible(selectBtn);
    await tester.tap(selectBtn);
    await tester.pumpAndSettle();

    // Cek parent detail tepat sekali dan tetap di halaman detail + refresh offer.
    expect(detailGetCount - detailCallsBefore, 1);
    expect(offerListRefreshCount - offerCallsBefore, 1);
    expect(find.text('Detail Permintaan'), findsOneWidget);
    expect(
      find.textContaining('Penawar yang dipilih sudah tidak tersedia'),
      findsOneWidget,
    );
  });
}
