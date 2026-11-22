import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savebite_mobile/request_board/data/dummy_requests.dart';
import 'package:savebite_mobile/request_board/models/food_request.dart';
import 'package:savebite_mobile/request_board/models/paginated_response.dart';
import 'package:savebite_mobile/request_board/models/request_offer.dart';
import 'package:savebite_mobile/request_board/screens/request_detail_page.dart';
import 'package:savebite_mobile/request_board/widgets/offer_card.dart';

Widget _buildDetailTestApp({
  required Widget child,
  Size size = const Size(360, 800),
}) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
      useMaterial3: true,
    ),
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: child,
    ),
  );
}

void main() {
  final ownedOfferedRequest = dummyFoodRequests[1]; // id: 2, owner: 1, selectedOfferId: 101
  final otherActiveRequest = dummyFoodRequests[2]; // id: 3, owner: 2, active, hasOffered: false
  final fulfilledOwnedRequest = dummyFoodRequests[4]; // id: 5, owner: 1, fulfilled
  final expiredOtherRequest = dummyFoodRequests[5]; // id: 6, owner: 4, expired

  testWidgets('Mobile and tablet layouts render all attributes without overflow',
      (WidgetTester tester) async {
    for (final size in [const Size(360, 800), const Size(840, 900)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        _buildDetailTestApp(
          size: size,
          child: RequestDetailPage(
            request: ownedOfferedRequest,
            currentUserId: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(ownedOfferedRequest.title), findsOneWidget);
      expect(find.text(ownedOfferedRequest.description), findsOneWidget);
      expect(find.text(ownedOfferedRequest.location), findsOneWidget);
      expect(find.text('Dapur Komunitas Menteng (Anda)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('Guest mode hides offers and write actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildDetailTestApp(
        child: RequestDetailPage(
          request: ownedOfferedRequest,
          currentUserId: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mode Tamu'), findsOneWidget);
    expect(find.byType(OfferCard), findsNothing);
    expect(find.text('Tawarkan Bantuan'), findsNothing);
    expect(find.text('Tandai Terpenuhi'), findsNothing);
    expect(find.text('Hapus Request'), findsNothing);
  });

  testWidgets(
    'Non-owner can offer when active, and stays disabled on 409 offers_closed even after refresh',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildDetailTestApp(
          child: RequestDetailPage(
            request: otherActiveRequest,
            currentUserId: 1,
            onRefreshDetail: (_) async => otherActiveRequest,
            onSubmitOffer: (_) async => throw const OffersClosedException(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final offerButton = find.widgetWithText(FilledButton, 'Tawarkan Bantuan');
      expect(offerButton, findsOneWidget);
      expect(tester.widget<FilledButton>(offerButton).onPressed, isNotNull);

      await tester.tap(offerButton);
      await tester.pumpAndSettle();

      expect(find.text('Penawaran ditutup'), findsWidgets);
      final disabledButton =
          find.widgetWithText(FilledButton, 'Penawaran ditutup');
      expect(tester.widget<FilledButton>(disabledButton).onPressed, isNull);

      // Refresh tidak boleh mengaktifkan kembali tombol selama halaman terbuka.
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(disabledButton).onPressed, isNull);
    },
  );

  testWidgets('Non-owner button is disabled when request is expired', (
    WidgetTester tester,
  ) async {
    final expiredNotOffered = FoodRequest(
      id: expiredOtherRequest.id,
      owner: expiredOtherRequest.owner,
      title: expiredOtherRequest.title,
      foodItem: expiredOtherRequest.foodItem,
      quantity: expiredOtherRequest.quantity,
      unit: expiredOtherRequest.unit,
      description: expiredOtherRequest.description,
      location: expiredOtherRequest.location,
      status: expiredOtherRequest.status,
      effectiveStatus: 'expired',
      expiresAt: expiredOtherRequest.expiresAt,
      offerCount: expiredOtherRequest.offerCount,
      hasOffered: false,
      selectedOfferId: null,
      createdAt: expiredOtherRequest.createdAt,
      updatedAt: expiredOtherRequest.updatedAt,
    );

    await tester.pumpWidget(
      _buildDetailTestApp(
        child: RequestDetailPage(
          request: expiredNotOffered,
          currentUserId: 99,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.widgetWithText(FilledButton, 'Tawarkan Bantuan');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
  });

  testWidgets(
    'Owner selection uses foodRequest.selectedOfferId, supports switching & pagination',
    (WidgetTester tester) async {
      // Offer 101 punya isSelected: true di model lama, namun selectedOfferId: 102
      // sehingga hanya Offer 102 yang harus tertandai Terpilih.
      final offer101 = RequestOffer(
        id: 101,
        requestId: 2,
        offeredBy: const RequestOwner(id: 2, displayName: 'Warung Berkah'),
        createdAt: DateTime.utc(2026, 11, 22, 10, 0),
        isSelected: true,
      );
      final offer102 = RequestOffer(
        id: 102,
        requestId: 2,
        offeredBy: const RequestOwner(id: 3, displayName: 'Panti Harapan'),
        createdAt: DateTime.utc(2026, 11, 22, 11, 0),
        isSelected: false,
      );
      final offer103 = RequestOffer(
        id: 103,
        requestId: 2,
        offeredBy: const RequestOwner(id: 4, displayName: 'Komunitas Depok'),
        createdAt: DateTime.utc(2026, 11, 22, 12, 0),
        isSelected: false,
      );

      final requestWith102 = FoodRequest(
        id: ownedOfferedRequest.id,
        owner: ownedOfferedRequest.owner,
        title: ownedOfferedRequest.title,
        foodItem: ownedOfferedRequest.foodItem,
        quantity: ownedOfferedRequest.quantity,
        unit: ownedOfferedRequest.unit,
        description: ownedOfferedRequest.description,
        location: ownedOfferedRequest.location,
        status: 'offered',
        effectiveStatus: 'offered',
        expiresAt: ownedOfferedRequest.expiresAt,
        offerCount: 3,
        hasOffered: false,
        selectedOfferId: 102,
        createdAt: ownedOfferedRequest.createdAt,
        updatedAt: ownedOfferedRequest.updatedAt,
      );

      await tester.pumpWidget(
        _buildDetailTestApp(
          child: RequestDetailPage(
            request: requestWith102,
            currentUserId: 1,
            initialOffers: [offer101, offer102],
            initialHasNextOffersPage: true,
            onLoadOffers: (_, page) async => PaginatedResponse<RequestOffer>(
              count: 3,
              page: page,
              pageSize: 2,
              totalPages: 2,
              results: [offer103],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Hanya satu badge "Terpilih", dan tombol ganti muncul pada offer lain.
      expect(find.text('Terpilih'), findsOneWidget);
      expect(find.text('Ganti ke Penawar Ini'), findsOneWidget);

      // Muat halaman penawar berikutnya.
      final loadMoreBtn = find.text('Muat Penawar Berikutnya');
      await tester.ensureVisible(loadMoreBtn);
      await tester.tap(loadMoreBtn);
      await tester.pumpAndSettle();

      expect(find.text('Komunitas Depok'), findsOneWidget);
      expect(find.text('Muat Penawar Berikutnya'), findsNothing);

      // Pilih penawar baru dari halaman 2.
      final switchButtons = find.text('Ganti ke Penawar Ini');
      expect(switchButtons, findsNWidgets(2));
      await tester.ensureVisible(switchButtons.last);
      await tester.tap(switchButtons.last);
      await tester.pumpAndSettle();

      expect(find.text('Terpilih'), findsOneWidget);
    },
  );

  testWidgets(
    'Owner delete button remains enabled on fulfilled request and shows confirmation',
    (WidgetTester tester) async {
      var deleteCalled = false;

      await tester.pumpWidget(
        _buildDetailTestApp(
          child: RequestDetailPage(
            request: fulfilledOwnedRequest,
            currentUserId: 1,
            onDeleteRequest: (_) async {
              deleteCalled = true;
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fulfillBtn =
          find.widgetWithText(FilledButton, 'Tandai Terpenuhi');
      expect(tester.widget<FilledButton>(fulfillBtn).onPressed, isNull);

      final deleteBtn = find.widgetWithText(OutlinedButton, 'Hapus Request');
      expect(tester.widget<OutlinedButton>(deleteBtn).onPressed, isNotNull);

      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(find.text('Hapus Permintaan?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
      await tester.pumpAndSettle();

      expect(deleteCalled, isTrue);
    },
  );

  testWidgets(
    'Logout while offers request is in-flight ignores stale response',
    (WidgetTester tester) async {
      final offersCompleter = Completer<PaginatedResponse<RequestOffer>?>();

      await tester.pumpWidget(
        _buildDetailTestApp(
          child: RequestDetailPage(
            request: ownedOfferedRequest,
            currentUserId: 1,
            onLoadOffers: (_, _) => offersCompleter.future,
          ),
        ),
      );
      await tester.pump();

      // Pengguna logout sebelum fetchOffers selesai.
      await tester.pumpWidget(
        _buildDetailTestApp(
          child: RequestDetailPage(
            request: ownedOfferedRequest,
            currentUserId: null,
            onLoadOffers: (_, _) => offersCompleter.future,
          ),
        ),
      );
      await tester.pump();

      // Respons lama tiba setelah logout.
      offersCompleter.complete(
        PaginatedResponse<RequestOffer>(
          count: 1,
          page: 1,
          pageSize: 20,
          totalPages: 1,
          results: getDummyOffersForRequest(2),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mode Tamu'), findsOneWidget);
      expect(find.byType(OfferCard), findsNothing);
    },
  );
}
