import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Provides utility methods for launching external communication apps
///
/// All methods are static and handle common formatting and error
/// scenarios. Each method takes a callback [onError] that is called
/// if the external app cannot be launched, typically an error snack
/// bar.
///
/// Usage examples:
/// ```dart
/// ContactActions.callNumber('9876543210', () => showErrorS(context, 'Could not launch dialer'));
/// ```
/// 
/// See shared/error_snackbars.dart for pre-built error snackbars
class ContactActions {

  /// Attempts to launch the phone dialer with the given [phoneNumber].
  ///
  /// If the dialer cannot be launched, the [onError] callback is invoked.
  static Future<void> callNumber(String phoneNumber, VoidCallback onError) async {
    try {
      final Uri uri = Uri(scheme: 'tel', path: phoneNumber);
      print('Trying to launch dialer with URI: $uri');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
      onError();
    } catch (e) {
      print('Error launching dialer: $e');
      onError();
    }
    
  }

  /// Attempts to launch WhatsApp with the given [phoneNumber].
  ///
  /// The phone number is formatted for Indian numbers (+91) if needed.
  /// If WhatsApp cannot be launched, the [onError] callback is invoked.
  static Future<void> openWhatsApp(String phoneNumber, VoidCallback onError) async {
    // Format the number for India (country code +91)
    try {
      String formattedNumber = phoneNumber.replaceAll(RegExp(r'\D'), ''); // Replaces non digits with empty string

      if (formattedNumber.length == 10) {
        // It's a 10-digit mobile number without country code
        formattedNumber = '91$formattedNumber';
      } else if (formattedNumber.startsWith('0') && formattedNumber.length == 11) {
        // Number starts with 0, extract last 10 digits
        formattedNumber = '91${formattedNumber.substring(1)}';
      } else if (formattedNumber.startsWith('+91') || (formattedNumber.startsWith('091'))) {
        // Extract just the last 10 digits and add 91
        formattedNumber = '91${formattedNumber.substring(formattedNumber.length - 10)}';
      }

      String text = Uri.encodeComponent('');
      final Uri appUri = Uri.parse("whatsapp://send?phone=$formattedNumber&text=$text");
      print('Trying to launch WhatsApp with URI: $appUri');
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalNonBrowserApplication);
        print('WhatsApp launched successfully using app URI');
        return;
      }

      final Uri webUri = Uri.parse("https://wa.me/$formattedNumber?text=$text");
      print('Trying to launch WhatsApp with URI: $webUri');
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        print('WhatsApp launched successfully using web URI');
        return;
      }
      print("Could not launch WhatsApp");
      onError();
    } catch (e) {
      print('Error formatting phone number: $e');
      onError();
    }
  }

  /// Attempts to launch the default email client with the given [email].
  ///
  /// Tries multiple URI schemes and fallbacks for compatibility.
  /// If no email client can be launched, the [onError] callback is invoked.
  static Future<void> openEmail(String email, VoidCallback onError) async {
    try {
      // First try standard mailto
      final Uri mailtoUri = Uri.parse('mailto:$email');
      print('Trying to launch email with URI: $mailtoUri');

      if (await canLaunchUrl(mailtoUri)) {
        await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
        print('Email app launched successfully with mailto');
        return;
      }

      // Try with query parameters for better compatibility
      final Uri mailtoQueryUri = Uri(scheme: 'mailto', path: email);
      print('Trying to launch email with path URI: $mailtoQueryUri');

      if (await canLaunchUrl(mailtoQueryUri)) {
        await launchUrl(mailtoQueryUri, mode: LaunchMode.externalApplication);
        print('Email app launched successfully with path');
        return;
      }

      // Try different launch modes for better emulator compatibility
      try {
        await launchUrl(mailtoUri, mode: LaunchMode.platformDefault);
        print('Email launched with platform default mode');
        return;
      } catch (platformError) {
        print('Platform default launch failed: $platformError');
      }

      // Try Gmail web interface as fallback
      final Uri gmailWebUri = Uri.parse(
        'https://mail.google.com/mail/?view=cm&to=$email',
      );
      print('Trying to launch Gmail web interface: $gmailWebUri');

      if (await canLaunchUrl(gmailWebUri)) {
        await launchUrl(gmailWebUri, mode: LaunchMode.externalApplication);
        print('Gmail web interface launched successfully');
        return;
      }

      print(
        'All email launch methods failed - likely no email apps or browser installed (common on emulators)',
      );
      onError();
    } catch (e) {
      print('Error launching email: $e');
      onError();
    }
  }

}