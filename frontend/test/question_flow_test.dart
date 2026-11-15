import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:houvast_frontend/main.dart';

void main() {
  testWidgets('alle drie de antwoorden verschijnen op het groepsbord', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: QuestionFlow(
              questions: ['Eerste vraag?', 'Tweede vraag?', 'Derde vraag?'],
            ),
          ),
        ),
      ),
    );

    const answers = [
      'Dit is mijn antwoord op de eerste vraag.',
      'Dit is mijn antwoord op de tweede vraag.',
      'Dit is mijn antwoord op de derde vraag.',
    ];

    for (var i = 0; i < answers.length; i++) {
      await tester.enterText(find.byType(TextField), answers[i]);
      await tester.pump();
      if (i < answers.length - 1) {
        await tester.tap(find.text('Volgende'));
        await tester.pump();
      }
    }

    // Labels op de bubbels van het groepsbord
    expect(find.text('Vraag 1'), findsOneWidget);
    expect(find.text('Vraag 2'), findsOneWidget);
    expect(find.text('Vraag 3'), findsOneWidget);
  });

  testWidgets('te kort antwoord komt niet op het bord', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: QuestionFlow(questions: ['Vraag?', 'Nog een?']),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'kort');
    await tester.pump();
    expect(find.text('Vraag 1'), findsNothing);
    expect(find.textContaining('Nog niet op het groepsbord'), findsOneWidget);
  });
}
