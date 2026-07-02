import 'package:flutter_test/flutter_test.dart';
import 'package:houvast_frontend/main.dart';

void main() {
  testWidgets('Houvast app renders shell', (WidgetTester tester) async {
    await tester.pumpWidget(const HouvastApp());

    expect(find.text('Houvast'), findsOneWidget);
    expect(find.text('Verder als gast'), findsOneWidget);
    expect(find.text('Inloggen als admin'), findsOneWidget);
  });
}
