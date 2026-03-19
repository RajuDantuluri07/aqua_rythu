import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqua_rythu/features/tray/tray_log_screen.dart';

void main() {
  group('TrayLogScreen Widget Tests', () {
    testWidgets('Tray count selector updates number of input rows',
        (WidgetTester tester) async {
      // Arrange: Pump the widget wrapped in ProviderScope
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: TrayLogScreen(pondId: 'p1', round: 1),
          ),
        ),
      );

      // Assert: Default state is 4 trays
      expect(find.text('Tray 1'), findsOneWidget);
      expect(find.text('Tray 4'), findsOneWidget);
      expect(find.text('Tray 5'), findsNothing);

      // Act: Switch to 2 Trays
      await tester.tap(find.widgetWithText(ChoiceChip, '2 Trays'));
      await tester.pumpAndSettle();

      // Assert: Only 2 rows visible
      expect(find.text('Tray 1'), findsOneWidget);
      expect(find.text('Tray 2'), findsOneWidget);
      expect(find.text('Tray 3'), findsNothing);
      expect(find.text('Tray 4'), findsNothing);

      // Act: Switch to 6 Trays
      await tester.tap(find.widgetWithText(ChoiceChip, '6 Trays'));
      await tester.pumpAndSettle();

      // Assert: Tray 1 exists
      expect(find.text('Tray 1'), findsOneWidget);
      
      // Scroll to find the last one (Tray 6) to ensure it rendered and list updated
      // Note: We use drag to scroll because scrollUntilVisible can be flaky with some ListViews in tests
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      
      expect(find.text('Tray 5'), findsOneWidget);
      expect(find.text('Tray 6'), findsOneWidget);
    });
  });
}