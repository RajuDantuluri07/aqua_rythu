import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqua_rythu/features/dashboard/dashboard_screen.dart';

void main() {
  group('FeedConsumptionChart Widget Tests', () {
    testWidgets('renders correct number of bars and labels based on data',
        (WidgetTester tester) async {
      // Arrange
      final testData = [10.0, 20.0, 0.0, 5.0];
      final testLabels = ['Mon', 'Tue', 'Wed', 'Thu'];

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedConsumptionChart(
              data: testData,
              labels: testLabels,
            ),
          ),
        ),
      );

      // Assert - Check Header
      expect(find.text("Feed Consumption (Last 7 Days)"), findsOneWidget);

      // Assert - Check Labels
      for (final label in testLabels) {
        expect(find.text(label), findsOneWidget);
      }

      // Assert - Check Values (0.0 should NOT display a text value above bar)
      expect(find.text('10.0'), findsOneWidget);
      expect(find.text('20.0'), findsOneWidget);
      expect(find.text('5.0'), findsOneWidget);
      expect(find.text('0.0'), findsNothing);

      // Assert - Check Bar Count
      // The chart structure uses an Expanded -> Row -> List<Column> (bars)
      final rowFinder = find.descendant(
        of: find.byType(Expanded),
        matching: find.byType(Row),
      );

      final row = tester.widget<Row>(rowFinder);
      expect(row.children.length, equals(testData.length));
    });
  });
}