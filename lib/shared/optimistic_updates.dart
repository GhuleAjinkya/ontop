import 'package:flutter/material.dart';

/// Generic optimistic updates service that can be used throughout the app
/// This provides a flexible way to handle instant UI updates with database fallback
class OptimisticUpdates {
  /// Performs an optimistic update operation
  ///
  /// [updateLocalState] - Function to update local state immediately
  /// [databaseOperation] - Async function to update database
  /// [revertLocalState] - Function to revert local state if database fails
  /// [onSuccess] - Optional callback when database operation succeeds
  /// [onError] - Optional callback when database operation fails
  /// [showSuccessMessage] - Optional success message to show user
  /// [showErrorMessage] - Optional error message to show user
  /// [context] - BuildContext for showing snackbars (optional)
  static Future<bool> perform<T>({
    required VoidCallback updateLocalState,
    required Future<T> Function() databaseOperation,
    required VoidCallback revertLocalState,
    VoidCallback? onSuccess,
    Function(dynamic error)? onError,
    String? showSuccessMessage,
    String? showErrorMessage,
    BuildContext? context,
  }) async {
    print("🟢 DEBUG OptimisticUpdates.perform: Starting optimistic update");
    
    // Step 1: Update local state immediately for instant UI feedback
    print("🟢 DEBUG OptimisticUpdates.perform: Calling updateLocalState");
    updateLocalState();
    
    try {
      // Step 2: Perform database operation in background
      print("🟢 DEBUG OptimisticUpdates.perform: Starting databaseOperation");
      final result = await databaseOperation();
      print("🟢 DEBUG OptimisticUpdates.perform: databaseOperation completed with result: $result");

      // Step 3: Handle success
      if (onSuccess != null) {
        print("🟢 DEBUG OptimisticUpdates.perform: Calling onSuccess callback");
        onSuccess();
        print("Succesful optimistic update");
      }

      if (showSuccessMessage != null && context != null) {
        print("🟢 DEBUG OptimisticUpdates.perform: Showing success message: $showSuccessMessage");
        _showSnackBar(context, showSuccessMessage, isError: false);
      }

      print("🟢 DEBUG OptimisticUpdates.perform: Operation completed successfully");
      return true;
    } catch (error) {
      print("🟢 DEBUG OptimisticUpdates.perform: Exception caught: $error");
      
      // Step 4: Revert local state if database operation failed
      print("🟢 DEBUG OptimisticUpdates.perform: Calling revertLocalState");
      revertLocalState();

      // Step 5: Handle error
      if (onError != null) {
        print("🟢 DEBUG OptimisticUpdates.perform: Calling onError callback");
        onError(error);
      }

      final errorMessage = showErrorMessage ?? 'Operation failed: $error';
      if (context != null) {
        print("🟢 DEBUG OptimisticUpdates.perform: Showing error message: $errorMessage");
        _showSnackBar(context, errorMessage, isError: true);
      }

      print('🟢 DEBUG OptimisticUpdates.perform: Optimistic update failed: $error');
      return false;
    }
  }

  /// Performs an optimistic list operation (add, remove, update item in list)
  ///
  /// [list] - The list to operate on
  /// [operation] - Type of operation: 'add', 'remove', 'update'
  /// [item] - The item to add/remove/update
  /// [updatePredicate] - Function to find item to update (for update operations)
  /// [databaseOperation] - Async function to update database
  /// [onSuccess] - Optional callback when database operation succeeds
  /// [onError] - Optional callback when database operation fails
  /// [showSuccessMessage] - Optional success message to show user
  /// [showErrorMessage] - Optional error message to show user
  /// [context] - BuildContext for showing snackbars (optional)
  static Future<bool> performListOperation<T>({
    required List<T> list,
    required String operation, // 'add', 'remove', 'update'
    required T item,
    bool Function(T)? updatePredicate,
    required Future<bool> Function() databaseOperation,
    VoidCallback? onSuccess,
    Function(dynamic error)? onError,
    String? showSuccessMessage,
    String? showErrorMessage,
    BuildContext? context,
  }) async {
    // Store original state for rollback
    final originalList = List<T>.from(list);

    // Step 1: Update local list immediately
    switch (operation.toLowerCase()) {
      case 'add':
        list.add(item);
        break;
      case 'remove':
        list.remove(item);
        break;
      case 'update':
        if (updatePredicate != null) {
          final index = list.indexWhere(updatePredicate);
          if (index != -1) {
            list[index] = item;
          }
        }
        break;
    }

    try {
      // Step 2: Perform database operation
      final success = await databaseOperation();

      if (!success) {
        throw Exception('Database operation returned false');
      }

      // Step 3: Handle success
      if (onSuccess != null) {
        onSuccess();
      }

      if (showSuccessMessage != null && context != null) {
        _showSnackBar(context, showSuccessMessage, isError: false);
      }

      return true;
    } catch (error) {
      // Step 4: Revert to original state
      list.clear();
      list.addAll(originalList);

      // Step 5: Handle error
      if (onError != null) {
        onError(error);
      }

      final errorMessage = showErrorMessage ?? 'Operation failed: $error';
      if (context != null) {
        _showSnackBar(context, errorMessage, isError: true);
      }

      print('Optimistic list operation failed: $error');
      return false;
    }
  }

  /// Performs an optimistic item update operation
  ///
  /// [list] - The list containing the item to update
  /// [findItem] - Function to find the item in the list
  /// [updateItem] - Function to create the updated item
  /// [databaseOperation] - Async function to update database
  /// [onSuccess] - Optional callback when database operation succeeds
  /// [onError] - Optional callback when database operation fails
  /// [showSuccessMessage] - Optional success message to show user
  /// [showErrorMessage] - Optional error message to show user
  /// [context] - BuildContext for showing snackbars (optional)
  static Future<bool> performItemUpdate<T>({
    required List<T> list,
    required bool Function(T) findItem,
    required T Function(T) updateItem,
    required Future<bool> Function() databaseOperation,
    VoidCallback? onSuccess,
    Function(dynamic error)? onError,
    String? showSuccessMessage,
    String? showErrorMessage,
    BuildContext? context,
  }) async {
    // Find the item and store original state
    final index = list.indexWhere(findItem);
    if (index == -1) return false;

    final originalItem = list[index];

    // Step 1: Update local item immediately
    list[index] = updateItem(originalItem);

    try {
      // Step 2: Perform database operation
      final success = await databaseOperation();

      if (!success) {
        throw Exception('Database operation returned false');
      }

      // Step 3: Handle success
      if (onSuccess != null) {
        onSuccess();
      }

      if (showSuccessMessage != null && context != null) {
        _showSnackBar(context, showSuccessMessage, isError: false);
      }

      return true;
    } catch (error) {
      // Step 4: Revert to original item
      if (index < list.length) {
        list[index] = originalItem;
      }

      // Step 5: Handle error
      if (onError != null) {
        onError(error);
      }

      final errorMessage = showErrorMessage ?? 'Update failed: $error';
      if (context != null) {
        _showSnackBar(context, errorMessage, isError: true);
      }

      print('Optimistic item update failed: $error');
      return false;
    }
  }

  /// Helper to show snackbar messages
  static void _showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: isError ? Colors.red.shade600 : null,
      ),
    );
  }
}
