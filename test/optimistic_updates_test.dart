import 'package:flutter_test/flutter_test.dart';
import 'package:asep_app/services/optimistic_updates.dart';

void main() {
  group('OptimisticUpdates Service Tests', () {
    test('perform should handle successful database operation', () async {
      bool localStateUpdated = false;
      bool databaseCalled = false;
      bool successCallbackCalled = false;

      final result = await OptimisticUpdates.perform<bool>(
        updateLocalState: () {
          localStateUpdated = true;
        },
        databaseOperation: () async {
          databaseCalled = true;
          return true;
        },
        revertLocalState: () {
          localStateUpdated = false;
        },
        onSuccess: () {
          successCallbackCalled = true;
        },
      );

      expect(result, true);
      expect(localStateUpdated, true);
      expect(databaseCalled, true);
      expect(successCallbackCalled, true);
    });

    test('perform should handle failed database operation', () async {
      bool localStateUpdated = false;
      bool databaseCalled = false;
      bool errorCallbackCalled = false;

      final result = await OptimisticUpdates.perform<bool>(
        updateLocalState: () {
          localStateUpdated = true;
        },
        databaseOperation: () async {
          databaseCalled = true;
          throw Exception('Database error');
        },
        revertLocalState: () {
          localStateUpdated = false;
        },
        onError: (error) {
          errorCallbackCalled = true;
        },
      );

      expect(result, false);
      expect(localStateUpdated, false); // Should be reverted
      expect(databaseCalled, true);
      expect(errorCallbackCalled, true);
    });

    test('performListOperation should handle successful add operation', () async {
      final list = <String>['item1', 'item2'];
      bool databaseCalled = false;

      final result = await OptimisticUpdates.performListOperation<String>(
        list: list,
        operation: 'add',
        item: 'item3',
        databaseOperation: () async {
          databaseCalled = true;
          return true;
        },
      );

      expect(result, true);
      expect(list.length, 3);
      expect(list.contains('item3'), true);
      expect(databaseCalled, true);
    });

    test('performListOperation should handle failed add operation', () async {
      final list = <String>['item1', 'item2'];
      final originalLength = list.length;

      final result = await OptimisticUpdates.performListOperation<String>(
        list: list,
        operation: 'add',
        item: 'item3',
        databaseOperation: () async {
          throw Exception('Database error');
        },
      );

      expect(result, false);
      expect(list.length, originalLength); // Should be reverted
      expect(list.contains('item3'), false);
    });

    test('performListOperation should handle successful remove operation', () async {
      final list = <String>['item1', 'item2', 'item3'];

      final result = await OptimisticUpdates.performListOperation<String>(
        list: list,
        operation: 'remove',
        item: 'item2',
        databaseOperation: () async {
          return true;
        },
      );

      expect(result, true);
      expect(list.length, 2);
      expect(list.contains('item2'), false);
    });

    test('performItemUpdate should handle successful update', () async {
      final items = <TestItem>[
        TestItem(id: '1', name: 'Item 1'),
        TestItem(id: '2', name: 'Item 2'),
      ];

      final result = await OptimisticUpdates.performItemUpdate<TestItem>(
        list: items,
        findItem: (item) => item.id == '1',
        updateItem: (item) => TestItem(id: item.id, name: 'Updated Item 1'),
        databaseOperation: () async {
          return true;
        },
      );

      expect(result, true);
      expect(items[0].name, 'Updated Item 1');
    });

    test('performItemUpdate should handle failed update', () async {
      final items = <TestItem>[
        TestItem(id: '1', name: 'Item 1'),
        TestItem(id: '2', name: 'Item 2'),
      ];
      final originalName = items[0].name;

      final result = await OptimisticUpdates.performItemUpdate<TestItem>(
        list: items,
        findItem: (item) => item.id == '1',
        updateItem: (item) => TestItem(id: item.id, name: 'Updated Item 1'),
        databaseOperation: () async {
          throw Exception('Database error');
        },
      );

      expect(result, false);
      expect(items[0].name, originalName); // Should be reverted
    });

    test('performItemUpdate should return false for non-existent item', () async {
      final items = <TestItem>[
        TestItem(id: '1', name: 'Item 1'),
      ];

      final result = await OptimisticUpdates.performItemUpdate<TestItem>(
        list: items,
        findItem: (item) => item.id == 'non-existent',
        updateItem: (item) => TestItem(id: item.id, name: 'Updated'),
        databaseOperation: () async {
          return true;
        },
      );

      expect(result, false);
    });
  });
}

// Test helper class
class TestItem {
  final String id;
  final String name;

  TestItem({required this.id, required this.name});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TestItem && other.id == id && other.name == name;
  }

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}
