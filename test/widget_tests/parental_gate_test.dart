import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dot_story/l10n/app_localizations.dart';
import 'package:dot_story/widgets/parental_gate.dart';

// ---------------------------------------------------------------------------
// Helper: widget that opens the parental gate on button tap
// ---------------------------------------------------------------------------

class _GateLauncher extends StatefulWidget {
  const _GateLauncher({required this.onResult});
  final void Function(bool) onResult;

  @override
  State<_GateLauncher> createState() => _GateLauncherState();
}

class _GateLauncherState extends State<_GateLauncher> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          key: const Key('open'),
          onPressed: () async {
            final result = await ParentalGate.show(context);
            widget.onResult(result);
          },
          child: const Text('Open gate'),
        ),
      ),
    );
  }
}

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: child,
    );

/// Parses "What is A op B?" and returns the expected answer.
int _computeAnswer(String questionText) {
  final match =
      RegExp(r'What is (\d+) ([+\-×]) (\d+)\?').firstMatch(questionText);
  expect(match, isNotNull, reason: 'Could not parse question: "$questionText"');
  final a = int.parse(match!.group(1)!);
  final op = match.group(2)!;
  final b = int.parse(match.group(3)!);
  switch (op) {
    case '+':
      return a + b;
    case '-':
      return a - b;
    case '×':
      return a * b;
    default:
      fail('Unknown operator: $op');
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ParentalGate dialog', () {
    testWidgets('cancel button resolves to false', (tester) async {
      bool? result;
      await tester.pumpWidget(
          _wrap(_GateLauncher(onResult: (r) => result = r)));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      expect(find.text('Parent Check'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, false);
    });

    testWidgets('wrong answer shows error and clears field', (tester) async {
      await tester.pumpWidget(
          _wrap(_GateLauncher(onResult: (_) {})));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '9999');
      await tester.tap(find.text('Submit'));
      await tester.pump();

      expect(find.text('Wrong answer. Try again!'), findsOneWidget);
      // Field should be cleared after wrong answer
      expect(tester.widget<TextField>(find.byType(TextField)).controller?.text,
          '');
    });

    testWidgets('correct answer resolves to true', (tester) async {
      bool? result;
      await tester.pumpWidget(
          _wrap(_GateLauncher(onResult: (r) => result = r)));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      final questionText = tester
          .widget<Text>(find.textContaining('What is'))
          .data!;
      final answer = _computeAnswer(questionText);

      await tester.enterText(find.byType(TextField), '$answer');
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(result, true);
    });
  });
}
