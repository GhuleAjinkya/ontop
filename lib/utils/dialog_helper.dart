import 'package:flutter/material.dart';

/// Helper class for creating consistent dialogs throughout the app
class DialogHelper {
  /// Shows a delete confirmation dialog with consistent styling
  ///
  /// Parameters:
  /// - context: BuildContext for the dialog
  /// - title: The title of the dialog (e.g. "Delete Contact?")
  /// - content: The message to show (e.g. "This will be permanently deleted")
  /// - onDelete: Function to call when Delete is pressed
  static Future<void> showDeleteConfirmation({
    required BuildContext context,
    required String title,
    required String content,
    required Function() onDelete,
  }) async {
    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.onPrimary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            title: Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              content,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontFamily: 'Poppins',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.tertiary,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  onDelete();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text('Delete', style: TextStyle(fontFamily: 'Poppins')),
              ),
            ],
          ),
    );
  }

  /// Shows a sign out confirmation dialog with consistent styling
  ///
  /// Parameters:
  /// - context: BuildContext for the dialog
  /// - onSignOut: Function to call when Sign Out is pressed
  static Future<void> showSignOutConfirmation({
    required BuildContext context,
    required Function() onSignOut,
  }) async {
    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.onPrimary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            title: Text(
              'Sign Out?',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              "You'll need to log back in to access your stored information.",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontFamily: 'Poppins',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.tertiary,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  onSignOut();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, // Red like delete buttons!
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  'Sign Out',
                  style: TextStyle(fontFamily: 'Poppins'),
                ),
              ),
            ],
          ),
    );
  }
}
