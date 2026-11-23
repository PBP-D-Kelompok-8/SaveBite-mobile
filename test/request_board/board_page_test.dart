import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:savebite_mobile/request_board/data/dummy_requests.dart';
import 'package:savebite_mobile/request_board/models/food_request.dart';
import 'package:savebite_mobile/request_board/providers/request_board_provider.dart';
import 'package:savebite_mobile/request_board/screens/request_board_page.dart';
import 'package:savebite_mobile/request_board/services/request_board_service.dart';
import 'package:savebite_mobile/request_board/services/session_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

RequestBoardService _createInMemoryService({
  int? currentUserId = 1,
}) {
  final store = List<FoodRequest>.from(dummyFoodRequests);
  var nextId = 1000;

  final sessionClient = SaveBiteSessionClient(
    baseUrl: 'https://example.test',
    httpClient: MockClient((request) async {
      final path = request.url.path;

      if (request.method == 'GET' && path == '/api/v1/requests/') {
        final params = request.url.queryParameters;
        final q = (params['q'] ?? '').trim().toLowerCase();
        final status = params['status'];
        final mine = params['mine'] == 'true';
        final sort = params['sort'] ?? 'newest';

        final filtered = store.where((item) {
          if (mine && currentUserId != null && item.owner.id != currentUserId) {
            return false;
          }
          if (status != null &&
              status.isNotEmpty &&
              item.effectiveStatus != status) {
            return false;
          }
          if (q.isNotEmpty) {
            final matches = item.title.toLowerCase().contains(q) ||
                item.foodItem.toLowerCase().contains(q) ||
                item.location.toLowerCase().contains(q);
            if (!matches) return false;
          }
          return true;
        }).toList();

        filtered.sort((a, b) => sort == 'oldest'
            ? a.createdAt.compareTo(b.createdAt)
            : b.createdAt.compareTo(a.createdAt));

        return http.Response(
          jsonEncode({
            'count': filtered.length,
            'page': 1,
            'page_size': 20,
            'total_pages': 1,
            'results': filtered.map((e) => e.toCacheJson()).toList(),
          }),
          200,
        );
      }

      if (request.method == 'POST' && path == '/api/v1/requests/') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final now = DateTime.now().toUtc();
        final created = FoodRequest(
          id: nextId++,
          owner: RequestOwner(
            id: currentUserId ?? 1,
            displayName: 'Dapur Komunitas Menteng',
          ),
          title: body['title'] as String,
          foodItem: body['food_item'] as String,
          quantity: body['quantity'].toString(),
          unit: body['unit'] as String,
          description: body['description'] as String? ?? '',
          location: body['location'] as String? ?? '',
          status: 'pending',
          effectiveStatus: 'pending',
          expiresAt: body['expires_at'] != null
              ? DateTime.parse(body['expires_at'] as String)
              : now.add(const Duration(hours: 24)),
          offerCount: 0,
          hasOffered: false,
          selectedOfferId: null,
          createdAt: now,
          updatedAt: now,
        );
        store.insert(0, created);
        return http.Response(jsonEncode(created.toCacheJson()), 201);
      }

      final detailMatch = RegExp(r'^/api/v1/requests/(\d+)/$').firstMatch(path);
      if (detailMatch != null) {
        final id = int.parse(detailMatch.group(1)!);
        if (request.method == 'GET') {
          final item = store.firstWhere((e) => e.id == id);
          return http.Response(jsonEncode(item.toCacheJson()), 200);
        }
        if (request.method == 'DELETE') {
          store.removeWhere((e) => e.id == id);
          return http.Response('', 204);
        }
      }

      final offersMatch =
          RegExp(r'^/api/v1/requests/(\d+)/offers/$').firstMatch(path);
      if (offersMatch != null && request.method == 'GET') {
        final id = int.parse(offersMatch.group(1)!);
        final offers = getDummyOffersForRequest(id);
        return http.Response(
          jsonEncode({
            'count': offers.length,
            'page': 1,
            'page_size': 20,
            'total_pages': 1,
            'results': offers
                .map((o) => {
                      'id': o.id,
                      'request_id': o.requestId,
                      'offered_by': o.offeredBy.toJson(),
                      'created_at': o.createdAt.toUtc().toIso8601String(),
                      'is_selected': o.isSelected,
                    })
                .toList(),
          }),
          200,
        );
      }

      return http.Response(jsonEncode({'detail': 'Not found.'}), 404);
    }),
  );

  if (currentUserId != null) {
    sessionClient.setSession(
      sessionId: 'test-session',
      csrfToken: 'test-csrf',
      userId: currentUserId,
      username: 'Dapur Komunitas Menteng',
    );
  }

  return RequestBoardService(sessionClient: sessionClient);
}

Widget _buildTestApp({
  Size size = const Size(360, 800),
  int? currentUserId = 1,
}) {
  SharedPreferences.setMockInitialValues({});
  final service = _createInMemoryService(currentUserId: currentUserId);
  final provider = RequestBoardProvider(service: service);

  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
      useMaterial3: true,
    ),
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: RequestBoardPage(provider: provider),
    ),
  );
}

void main() {
  testWidgets('Mobile layout (< 600px) uses ListView without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildTestApp(size: const Size(360, 800)));
    await tester.pumpAndSettle();

    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(SliverGrid), findsNothing);
    expect(find.text('Butuh Beras Putih untuk Dapur Umum'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tablet layout (>= 600px) uses 2-column grid without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildTestApp(size: const Size(800, 1000)));
    await tester.pumpAndSettle();

    expect(find.byType(SliverGrid), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
    expect(find.text('Butuh Beras Putih untuk Dapur Umum'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Search input debounces for 350ms before filtering', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildTestApp(size: const Size(400, 900)));
    await tester.pumpAndSettle();

    final searchField = find.byType(TextField);
    expect(searchField, findsOneWidget);

    await tester.enterText(searchField, 'Beras');
    await tester.pump(const Duration(milliseconds: 200));

    // Sebelum 350ms berlalu, item lain masih tampil.
    expect(find.text('Telur Ayam Segar untuk Sarapan Anak'), findsOneWidget);

    // Setelah melewati 350ms debounce, daftar terfilter.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.text('Butuh Beras Putih untuk Dapur Umum'), findsOneWidget);
    expect(find.text('Telur Ayam Segar untuk Sarapan Anak'), findsNothing);

    // Tombol hapus pencarian langsung mengembalikan daftar.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Telur Ayam Segar untuk Sarapan Anak'), findsOneWidget);
  });

  testWidgets('Status dropdown, Permintaan Saya, and empty state reset work', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildTestApp(size: const Size(400, 900)));
    await tester.pumpAndSettle();

    // Filter status "Kedaluwarsa" melalui dropdown.
    await tester.tap(find.text('Semua').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kedaluwarsa').last);
    await tester.pumpAndSettle();

    expect(find.text('Susu UHT Kemasan untuk Balita'), findsOneWidget);
    expect(find.text('Butuh Beras Putih untuk Dapur Umum'), findsNothing);

    // Toggle "Permintaan Saya" (hanya request milik dummyCurrentUserId = 1).
    await tester.tap(find.widgetWithText(FilterChip, 'Permintaan Saya'));
    await tester.pumpAndSettle();

    expect(find.text('Susu UHT Kemasan untuk Balita'), findsNothing);
    expect(find.text('Roti Tawar Gandum untuk Snack Pagi'), findsOneWidget);

    // Pencarian tanpa hasil menampilkan empty state + tombol Reset Filter.
    await tester.enterText(find.byType(TextField), 'TidakAdaItemIni');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Tidak ada permintaan yang cocok'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Reset Filter'));
    await tester.pumpAndSettle();

    expect(find.text('Butuh Beras Putih untuk Dapur Umum'), findsOneWidget);
  });

  testWidgets('Guest mode disables Permintaan Saya filter chip', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildTestApp(size: const Size(400, 900), currentUserId: null),
    );
    await tester.pumpAndSettle();

    final chip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Permintaan Saya'),
    );
    expect(chip.onSelected, isNull);
  });

  testWidgets('Tapping RequestCard opens RequestDetailPage and syncs delete', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildTestApp(size: const Size(400, 900)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Butuh Beras Putih untuk Dapur Umum'));
    await tester.pumpAndSettle();

    expect(find.text('Detail Permintaan'), findsOneWidget);

    final deleteBtn = find.widgetWithText(OutlinedButton, 'Hapus Request');
    await tester.ensureVisible(deleteBtn);
    await tester.tap(deleteBtn);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
    await tester.pumpAndSettle();

    expect(find.text('Food Rescue Request Board'), findsOneWidget);
    expect(find.text('Butuh Beras Putih untuk Dapur Umum'), findsNothing);
  });

  testWidgets('Tapping FAB opens RequestFormPage and adds created request', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildTestApp(size: const Size(400, 900)));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Buat Permintaan Baru'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Judul Permintaan *'),
      'Butuh Gula Pasir',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nama Bahan Makanan *'),
      'Gula Pasir',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Jumlah *'),
      '3',
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

    expect(find.text('Food Rescue Request Board'), findsOneWidget);
    expect(find.text('Butuh Gula Pasir'), findsOneWidget);
  });

  testWidgets('Offline fallback shows cached items and offline banner', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      RequestBoardProvider.publicPage1CacheKey: jsonEncode([
        FoodRequest(
          id: 501,
          owner: const RequestOwner(id: 2, displayName: 'Warga Tebet'),
          title: 'Cached Offline Request',
          foodItem: 'Wortel',
          quantity: '1.00',
          unit: 'kg',
          description: '',
          location: 'Tebet',
          status: 'pending',
          effectiveStatus: 'pending',
          offerCount: 0,
          hasOffered: false,
          createdAt: DateTime.utc(2026, 11, 20),
          updatedAt: DateTime.utc(2026, 11, 20),
        ).toCacheJson(),
      ]),
    });

    final sessionClient = SaveBiteSessionClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((_) async {
        throw http.ClientException('Offline');
      }),
    );
    final provider = RequestBoardProvider(
      service: RequestBoardService(sessionClient: sessionClient),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RequestBoardPage(provider: provider),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Mode Offline — menampilkan data terakhir tersimpan'),
      findsOneWidget,
    );
    expect(find.text('Coba Lagi'), findsOneWidget);
    expect(find.text('Cached Offline Request'), findsOneWidget);
  });
}
