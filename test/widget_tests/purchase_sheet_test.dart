import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dot_story/screens/story_selection/purchase_sheet.dart';

void main() {
  testWidgets('PurchaseSheet shows Unlock All Stories title', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: PurchaseSheet()),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Unlock All Stories'), findsOneWidget);
  });

  testWidgets('PurchaseSheet shows Unlock Now and Restore Purchase buttons', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: PurchaseSheet()),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Unlock Now'), findsOneWidget);
    expect(find.text('Restore Purchase'), findsOneWidget);
  });
}
