import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

/// A utility class to handle consistent date and time formatting across the app
class DateFormatter {
  /// Format date in dd/MM/yy format
  /// Example: 03/06/25
  static String formatDate(DateTime date) {
    return DateFormat('dd/MM/yy').format(date);
  }

  /// Format time in 24-hour format (HH:mm)
  /// Example: 14:05
  static String formatTime(DateTime time) {
    return DateFormat('HH:mm').format(time);
  }

  /// Format time from TimeOfDay in 24-hour format (HH:mm)
  static String formatTimeOfDay(TimeOfDay timeOfDay) {
    final now = DateTime.now();
    final dateTime = DateTime(
      now.year,
      now.month,
      now.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );
    return formatTime(dateTime);
  }

  /// Format date and time together in dd/MM/yy HH:mm format
  /// Example: 03/06/25 14:05
  static String formatDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yy HH:mm').format(dateTime);
  }

  /// Format completed task date with "Completed on" prefix
  /// Example: "Completed on 03/06/25"
  static String formatCompletedDate(DateTime date) {
    return "Completed on ${formatDate(date)}";
  }

  /// Configure date picker to use our consistent format
  static Widget datePickerBuilder(BuildContext context, Widget? child) {
    return Theme(
      data: Theme.of(context).copyWith(
        // Use our preferred dd/MM/yy format for date display
        textTheme: Theme.of(context).textTheme.copyWith(
          // Date format display
          bodyMedium: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontFamily: 'Poppins'),
        ),
      ),
      child: child!,
    );
  }
}
