import 'package:flutter_test/flutter_test.dart';
import 'package:houvast_frontend/main.dart';

void main() {
  testWidgets('Houvast toont inlogscherm', (WidgetTester tester) async {
    await tester.pumpWidget(const HouvastApp());
    await tester.pump();

    expect(find.text('Houvast'), findsOneWidget);
    expect(find.text('Inloggen'), findsOneWidget);
    expect(find.text('Beheerder?'), findsOneWidget);
  });
}
