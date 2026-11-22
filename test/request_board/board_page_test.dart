import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savebite_mobile/request_board/screens/request_board_page.dart';

Widget _buildTestApp({
  Size size = const Size(360, 800),
  int? currentUserId = 1,
}) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
      useMaterial3: true,
    ),
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: RequestBoardPage(currentUserId: currentUserId),
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
    expect(find.byType(GridView), findsNothing);
    expect(find.text('Butuh Beras Putih untuk Dapur Umum'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tablet layout (>= 600px) uses 2-column GridView without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildTestApp(size: const Size(800, 1000)));
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsOneWidget);
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
}
