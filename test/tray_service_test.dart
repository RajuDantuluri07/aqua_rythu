import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqua_rythu/core/services/tray_service.dart';

void main() {
  // ---------------------------------------------------------------------------
  // sanitizeObservations
  // ---------------------------------------------------------------------------
  group('TrayService.sanitizeObservations', () {
    test('null returns empty map', () {
      expect(TrayService.sanitizeObservations(null), isEmpty);
    });

    test('empty map returns empty map', () {
      expect(TrayService.sanitizeObservations({}), isEmpty);
    });

    test('integer keys are stringified', () {
      final result = TrayService.sanitizeObservations({
        1: ['heavy'],
        2: ['light'],
      });
      expect(result.keys, containsAll(['1', '2']));
      expect(result['1'], equals(['heavy']));
      expect(result['2'], equals(['light']));
    });

    test('result is always JSON-encodable', () {
      final result = TrayService.sanitizeObservations({
        3: ['medium', 'light'],
        7: ['empty'],
      });
      expect(() => jsonEncode(result), returnsNormally);
    });

    test('list values are copied defensively', () {
      final original = <int, List<String>>{1: ['heavy']};
      final result = TrayService.sanitizeObservations(original);
      original[1]!.add('mutated');
      expect(result['1'], equals(['heavy']));
    });

    test('large round numbers become string keys', () {
      final result = TrayService.sanitizeObservations({99: ['light']});
      expect(result.containsKey('99'), isTrue);
    });

    test('multiple values per tray are preserved', () {
      final result = TrayService.sanitizeObservations({
        1: ['medium', 'heavy', 'light'],
      });
      expect(result['1'], hasLength(3));
    });

    test('empty value lists are preserved', () {
      final result = TrayService.sanitizeObservations({1: []});
      expect(result['1'], isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // sanitizeObservations — JSON output shape
  // ---------------------------------------------------------------------------
  group('TrayService.sanitizeObservations JSON shape', () {
    test('encodes to valid JSON string', () {
      final result = TrayService.sanitizeObservations({
        1: ['heavy'],
        2: ['light', 'medium'],
      });
      final encoded = jsonEncode(result);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      expect(decoded['1'], equals(['heavy']));
      expect(decoded['2'], equals(['light', 'medium']));
    });

    test('null input produces encodable empty map', () {
      final result = TrayService.sanitizeObservations(null);
      expect(() => jsonEncode(result), returnsNormally);
      expect(jsonEncode(result), equals('{}'));
    });

    test('output map has only String keys', () {
      final result = TrayService.sanitizeObservations({
        1: ['heavy'],
        42: ['light'],
      });
      for (final key in result.keys) {
        expect(key, isA<String>());
      }
    });
  });
}
