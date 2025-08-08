import 'package:flutter/material.dart';

class ErrorSnackbars {
  static void showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 4),
        showCloseIcon: true,
      ),
    );
  }

  static void whileLaunchingExternalApp(BuildContext context, String appName) {
    showErrorSnackbar(
      context,
      'Unable to launch $appName',
    );
  }
}