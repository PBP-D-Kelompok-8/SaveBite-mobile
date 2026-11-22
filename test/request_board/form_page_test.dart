import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savebite_mobile/request_board/models/food_request.dart';
import 'package:savebite_mobile/request_board/screens/request_form_page.dart';

Widget _buildFormTestApp({
  required Widget child,
  Size size = const Size(420, 900),
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
  testWidgets('Step 1 validation blocks advancing to Step 2', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildFormTestApp(child: const RequestFormPage()),
    );
    await tester.pumpAndSettle();

    // Tekan Lanjut tanpa mengisi field wajib.
    await tester.tap(find.text('Lanjut').first);
    await tester.pumpAndSettle();

    expect(find.text('Judul permintaan wajib diisi.'), findsOneWidget);
    expect(find.text('Nama bahan makanan wajib diisi.'), findsOneWidget);
    expect(find.text('Jumlah wajib diisi.'), findsOneWidget);
    expect(find.text('Pilih satuan bahan makanan.'), findsOneWidget);

    // Tetap di Langkah 1 (currentStep == 0).
    expect(tester.widget<Stepper>(find.byType(Stepper)).currentStep, 0);
  });

  testWidgets('Quantity validator rejects invalid decimals and out-of-range', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildFormTestApp(child: const RequestFormPage()),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Judul Permintaan *'),
      'Butuh Beras',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nama Bahan Makanan *'),
      'Beras',
    );

    // Lebih dari 2 angka desimal.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Jumlah *'),
      '1.234',
    );
    await tester.tap(find.text('Lanjut').first);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Gunakan angka valid dengan maksimal 2 angka desimal (mis. 2.50).',
      ),
      findsOneWidget,
    );

    // Di bawah 0.01.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Jumlah *'),
      '0.00',
    );
    await tester.tap(find.text('Lanjut').first);
    await tester.pumpAndSettle();
    expect(
      find.text('Jumlah harus antara 0.01 dan 999999.99.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Valid Step 1 advances to Step 2 and empty expires_at omits key in payload',
    (WidgetTester tester) async {
      FoodRequestCreatePayload? capturedPayload;

      await tester.pumpWidget(
        _buildFormTestApp(
          child: RequestFormPage(
            onSubmit: (payload) async {
              capturedPayload = payload;
              return null;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Judul Permintaan *'),
        'Butuh Minyak Goreng',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nama Bahan Makanan *'),
        'Minyak Sawit',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Jumlah *'),
        '2.5',
      );

      // Pilih satuan dari dropdown.
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('liter').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lanjut').first);
      await tester.pumpAndSettle();

      // Sudah masuk Langkah 2 & ringkasan terlihat.
      expect(find.text('Ringkasan Permintaan'), findsOneWidget);

      final submitBtn = find.text('Kirim Permintaan');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(capturedPayload, isNotNull);
      final json = capturedPayload!.toJson();
      expect(json['title'], 'Butuh Minyak Goreng');
      expect(json['food_item'], 'Minyak Sawit');
      expect(json['quantity'], '2.50');
      expect(json['unit'], 'liter');
      expect(json['location'], '');
      expect(json['description'], '');
      expect(json.containsKey('expires_at'), isFalse);
    },
  );

  testWidgets(
    'Server field validation errors render directly below related inputs',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildFormTestApp(
          child: RequestFormPage(
            onSubmit: (_) async => throw const RequestFormValidationException(
              fieldErrors: {
                'quantity': 'Jumlah melebihi batas server.',
                'expires_at': 'Tenggat waktu tidak valid.',
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Judul Permintaan *'),
        'Butuh Telur',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nama Bahan Makanan *'),
        'Telur Ayam',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Jumlah *'),
        '10',
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('butir').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lanjut').first);
      await tester.pumpAndSettle();

      final submitBtn = find.text('Kirim Permintaan');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Karena ada error di Langkah 1 (quantity), Stepper kembali ke Langkah 1
      // dan menampilkan pesan error server di bawah field terkait.
      expect(find.text('Jumlah melebihi batas server.'), findsOneWidget);
    },
  );
}
