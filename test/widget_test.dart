import 'package:flutter_test/flutter_test.dart';
import 'package:savebite_mobile/main.dart';

void main() {
  testWidgets('SaveBite home page renders title and description', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('SaveBite'), findsOneWidget);
    expect(find.text('SaveBite: Food Waste Management'), findsOneWidget);
  });
}
