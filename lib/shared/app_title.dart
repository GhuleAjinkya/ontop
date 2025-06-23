import 'package:flutter/material.dart';
import '../main.dart';

class AppTitle extends StatelessWidget {
  final TextStyle? style;
  final bool isMain;

  const AppTitle({
    super.key,
    this.style,
    this.isMain = false,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!isMain) { // Only navigate if not already on main screen
          navigateToHome();
        }
      },
      child: Text(
        'ontop.',
        style: style ?? TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 40,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }
}
