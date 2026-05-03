import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aqua_rythu/core/services/inventory_service.dart';

// Create manual fake classes for Supabase to avoid Mockito Future issues
class FakeSupabaseClient extends Fake implements SupabaseClient {
  final Object? result;
  final Exception? error;
  int fromCallCount = 0;

  FakeSupabaseClient({this.result, this.error});

  @override
  SupabaseQueryBuilder from(String table) {
    fromCallCount++;
    if (table == 'inventory_items') {
      return FakeSupabaseQueryBuilder(result: result, error: error);
    }
    throw UnimplementedError('Unexpected table $table');
  }
}

class FakeSupabaseQueryBuilder extends Fake implements SupabaseQueryBuilder {
  final Object? result;
  final Exception? error;

  FakeSupabaseQueryBuilder({this.result, this.error});

  @override
  PostgrestFilterBuilder<dynamic> insert(Object values, {bool defaultToNull = true}) {
    if (error != null) {
      throw error!; // Throw synchronously here instead of waiting for then()
    }
    return FakePostgrestFilterBuilder(result: result, error: error);
  }
}

class FakePostgrestFilterBuilder extends Fake implements PostgrestFilterBuilder<dynamic> {
  final dynamic result;
  final Exception? error;

  FakePostgrestFilterBuilder({this.result, this.error});

  @override
  Future<U> then<U>(FutureOr<U> Function(dynamic value) onValue, {Function? onError}) async {
    return onValue(result);
  }
}

void main() {
  group('InventoryService.createInventoryItems', () {
    test('returns early when items list is empty', () async {
      final fakeClient = FakeSupabaseClient();
      final inventoryService = InventoryService(client: fakeClient);

      await inventoryService.createInventoryItems([]);
      expect(fakeClient.fromCallCount, 0); // verify from wasn't called
    });

    test('calls supabase insert when list is not empty', () async {
      final fakeClient = FakeSupabaseClient(result: []);
      final inventoryService = InventoryService(client: fakeClient);

      final items = [
        {'name': 'Test Item 1', 'category': 'feed'}
      ];

      await inventoryService.createInventoryItems(items);
      expect(fakeClient.fromCallCount, 1);
    });

    test('rethrows exception on supabase error', () async {
      final fakeClient = FakeSupabaseClient(error: Exception('Supabase error'));
      final inventoryService = InventoryService(client: fakeClient);

      final items = [
        {'name': 'Test Item 1', 'category': 'feed'}
      ];

      await expectLater(
        () => inventoryService.createInventoryItems(items),
        throwsA(isA<Exception>()),
      );
    });

    test('throws ArgumentError on malformed items', () async {
      final fakeClient = FakeSupabaseClient();
      final inventoryService = InventoryService(client: fakeClient);

      final items = [
        {'name': 'Test Item 1'} // missing category
      ];

      await expectLater(
        () => inventoryService.createInventoryItems(items),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
