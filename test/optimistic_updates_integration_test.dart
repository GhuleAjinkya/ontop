import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:asep_app/services/optimistic_updates.dart';

void main() {
  group('Optimistic Updates Integration Tests', () {
    testWidgets('Simple optimistic update with success', (
      WidgetTester tester,
    ) async {
      // Test data
      final data = <String>['item1', 'item2'];
      bool databaseCalled = false;

      // Mock widget to test in
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    await OptimisticUpdates.performListOperation<String>(
                      list: data,
                      operation: 'add',
                      item: 'item3',
                      databaseOperation: () async {
                        databaseCalled = true;
                        return true;
                      },
                      showSuccessMessage: 'Item added successfully!',
                      context: context,
                    );
                  },
                  child: Text('Add Item'),
                );
              },
            ),
          ),
        ),
      );

      // Test successful operation
      await tester.tap(find.text('Add Item'));
      await tester.pump();

      expect(data.length, 3); // Should be immediately added
      expect(data.contains('item3'), true);
      expect(databaseCalled, true);
    });

    testWidgets('Simple optimistic update with failure and rollback', (
      WidgetTester tester,
    ) async {
      // Test data
      final data = <String>['item1', 'item2'];
      bool databaseCalled = false;

      // Mock widget to test in
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    await OptimisticUpdates.performListOperation<String>(
                      list: data,
                      operation: 'add',
                      item: 'item3',
                      databaseOperation: () async {
                        databaseCalled = true;
                        throw Exception('Database error');
                      },
                      showErrorMessage: 'Failed to add item',
                      context: context,
                    );
                  },
                  child: Text('Add Item'),
                );
              },
            ),
          ),
        ),
      );

      // Test failed operation with rollback
      final originalLength = data.length;
      await tester.tap(find.text('Add Item'));
      await tester.pump();
      await tester.pump(Duration(milliseconds: 100)); // Allow error handling

      expect(data.length, originalLength); // Should be reverted
      expect(data.contains('item3'), false);
      expect(databaseCalled, true);
    });

    testWidgets('Item update optimistic update', (WidgetTester tester) async {
      // Test data
      final items = <TestItem>[
        TestItem(id: '1', name: 'Item 1', status: false),
        TestItem(id: '2', name: 'Item 2', status: false),
      ];

      bool databaseCalled = false;

      // Mock widget to test in
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    await OptimisticUpdates.performItemUpdate<TestItem>(
                      list: items,
                      findItem: (item) => item.id == '1',
                      updateItem:
                          (item) => TestItem(
                            id: item.id,
                            name: item.name,
                            status: true,
                          ),
                      databaseOperation: () async {
                        databaseCalled = true;
                        return true;
                      },
                      showSuccessMessage: 'Item updated!',
                      context: context,
                    );
                  },
                  child: Text('Update Item'),
                );
              },
            ),
          ),
        ),
      );

      // Test successful update
      await tester.tap(find.text('Update Item'));
      await tester.pump();

      expect(items[0].status, true); // Should be immediately updated
      expect(databaseCalled, true);
    });

    testWidgets('Item update with failure and rollback', (
      WidgetTester tester,
    ) async {
      // Test data
      final items = <TestItem>[
        TestItem(id: '1', name: 'Item 1', status: false),
        TestItem(id: '2', name: 'Item 2', status: false),
      ];

      bool databaseCalled = false;

      // Mock widget to test in
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    await OptimisticUpdates.performItemUpdate<TestItem>(
                      list: items,
                      findItem: (item) => item.id == '1',
                      updateItem:
                          (item) => TestItem(
                            id: item.id,
                            name: item.name,
                            status: true,
                          ),
                      databaseOperation: () async {
                        databaseCalled = true;
                        throw Exception('Database error');
                      },
                      showErrorMessage: 'Failed to update item',
                      context: context,
                    );
                  },
                  child: Text('Update Item'),
                );
              },
            ),
          ),
        ),
      );

      // Test failed update with rollback
      await tester.tap(find.text('Update Item'));
      await tester.pump();
      await tester.pump(Duration(milliseconds: 100)); // Allow error handling

      expect(items[0].status, false); // Should be reverted
      expect(databaseCalled, true);
    });

    testWidgets('Remove operation optimistic update', (
      WidgetTester tester,
    ) async {
      // Test data
      final items = <TestItem>[
        TestItem(id: '1', name: 'Item 1', status: false),
        TestItem(id: '2', name: 'Item 2', status: false),
      ];

      bool databaseCalled = false;

      // Mock widget to test in
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    final itemToRemove = items.firstWhere(
                      (item) => item.id == '1',
                    );

                    await OptimisticUpdates.performListOperation<TestItem>(
                      list: items,
                      operation: 'remove',
                      item: itemToRemove,
                      databaseOperation: () async {
                        databaseCalled = true;
                        return true;
                      },
                      showSuccessMessage: 'Item removed!',
                      context: context,
                    );
                  },
                  child: Text('Remove Item'),
                );
              },
            ),
          ),
        ),
      );

      // Test successful removal
      final originalLength = items.length;
      await tester.tap(find.text('Remove Item'));
      await tester.pump();

      expect(items.length, originalLength - 1); // Should be immediately removed
      expect(items.any((item) => item.id == '1'), false);
      expect(databaseCalled, true);
    });

    test('Complex state management scenario', () async {
      // Simulate task completion toggle between todo and completed lists
      final todoItems = <TestItem>[
        TestItem(id: '1', name: 'Task 1', status: false),
        TestItem(id: '2', name: 'Task 2', status: false),
      ];
      final completedItems = <TestItem>[];

      bool databaseCalled = false;

      // Test moving item from todo to completed
      final result = await OptimisticUpdates.perform<bool>(
        updateLocalState: () {
          // Move item from todo to completed
          final task = todoItems.removeAt(0);
          completedItems.add(
            TestItem(id: task.id, name: task.name, status: true),
          );
        },
        databaseOperation: () async {
          databaseCalled = true;
          return true;
        },
        revertLocalState: () {
          // Revert: move item back to todo
          final task = completedItems.removeAt(0);
          todoItems.add(TestItem(id: task.id, name: task.name, status: false));
        },
      );

      expect(result, true);
      expect(todoItems.length, 1);
      expect(completedItems.length, 1);
      expect(completedItems[0].status, true);
      expect(databaseCalled, true);
    });

    test('Complex state management with failure and rollback', () async {
      // Simulate task completion toggle between todo and completed lists
      final todoItems = <TestItem>[
        TestItem(id: '1', name: 'Task 1', status: false),
        TestItem(id: '2', name: 'Task 2', status: false),
      ];
      final completedItems = <TestItem>[];

      bool databaseCalled = false;

      // Test moving item from todo to completed (with failure)
      final result = await OptimisticUpdates.perform<bool>(
        updateLocalState: () {
          // Move item from todo to completed
          final task = todoItems.removeAt(0);
          completedItems.add(
            TestItem(id: task.id, name: task.name, status: true),
          );
        },
        databaseOperation: () async {
          databaseCalled = true;
          throw Exception('Database error');
        },
        revertLocalState: () {
          // Revert: move item back to todo
          final task = completedItems.removeAt(0);
          todoItems.add(TestItem(id: task.id, name: task.name, status: false));
        },
      );

      expect(result, false);
      expect(todoItems.length, 2); // Should be reverted
      expect(completedItems.length, 0); // Should be reverted
      expect(databaseCalled, true);
    });

    test('Bulk operations with optimistic updates', () async {
      // Test data for bulk operations
      final items = <TestItem>[
        TestItem(id: '1', name: 'Item 1', status: false),
        TestItem(id: '2', name: 'Item 2', status: false),
        TestItem(id: '3', name: 'Item 3', status: true),
      ];

      bool databaseCalled = false;

      // Test bulk status change
      final result = await OptimisticUpdates.perform<bool>(
        updateLocalState: () {
          for (var item in items) {
            if (!item.status) {
              // Mark non-completed items as completed
              items[items.indexOf(item)] = TestItem(
                id: item.id,
                name: item.name,
                status: true,
              );
            }
          }
        },
        databaseOperation: () async {
          databaseCalled = true;
          return true;
        },
        revertLocalState: () {
          // Revert changes
          items[0] = TestItem(id: '1', name: 'Item 1', status: false);
          items[1] = TestItem(id: '2', name: 'Item 2', status: false);
        },
      );

      expect(result, true);
      expect(databaseCalled, true);
      expect(items[0].status, true); // Should be completed
      expect(items[1].status, true); // Should be completed
      expect(items[2].status, true); // Already completed
    });
  });
}

// Test helper class
class TestItem {
  final String id;
  final String name;
  final bool status;

  TestItem({required this.id, required this.name, required this.status});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TestItem &&
        other.id == id &&
        other.name == name &&
        other.status == status;
  }

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ status.hashCode;
}
