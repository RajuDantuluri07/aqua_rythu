import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqua_rythu/features/pond/widgets/operation_item.dart';

void main() {
  group('OperationItem Widget Tests', () {
    testWidgets('OperationItem displays title and icon correctly',
        (WidgetTester tester) async {
      const String testTitle = 'Water Test';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OperationItem(testTitle),
          ),
        ),
      );

      expect(find.text(testTitle), findsOneWidget);
      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.byIcon(Icons.circle), findsOneWidget);
    });

    testWidgets('OperationItem triggers onTap callback when tapped',
        (WidgetTester tester) async {
      bool wasTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OperationItem(
              'Tap Me',
              onTap: () => wasTapped = true,
            ),
          ),
        ),
      );

      // Perform tap
      await tester.tap(find.byType(OperationItem));
      await tester.pump();

      // Verify callback
      expect(wasTapped, isTrue);
    });
  });
}