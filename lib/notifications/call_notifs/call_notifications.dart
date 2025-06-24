import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:phone_state/phone_state.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../contacts/contacts_adapter.dart';
import '../../shared/user_session.dart';
import '../../contacts/contact_model.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart';

class CallNotificationService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  List<Contact> globalContacts = [];
  
  Future<void> reloadNotificationPreference() async {
    // You can simply restart the listener, or just reload the preference if you cache it
    listenForCalls();
  }
  String normalizeNumber(String number) {
    // Remove all non-digit characters
    String digits = number.replaceAll(RegExp(r'\D'), '');
    // If it starts with '91' and is longer than 10 digits, use last 10 digits
    if (digits.length > 10 && digits.startsWith('91')) {
      digits = digits.substring(digits.length - 10);
    }
    return digits;
  }

  Future<void> updateContacts() async {
    print("Updating notification service contacts...");
    try {
      List<Map<String, dynamic>> fetchedContacts = await ContactsAdapter.getContacts();
      globalContacts = fetchedContacts.map((doc) => Contact.fromMongo(doc)).toList();
      print("Updated notification contacts: ${globalContacts.length} contacts loaded");
    } catch (e) {
      print("Error updating notification contacts: $e");
    }
  }

  Future<void> init() async {
    // Request permissions first
    await _requestPermissions();
    
    final AndroidNotificationChannel channel = AndroidNotificationChannel(
      'call_channel',
      'Incoming Calls',
      description: 'Notification channel for incoming calls',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
    );

    // Create the Android notification channel
    await _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);

    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = 
        InitializationSettings(android: androidSettings);
    
    await loadContactsFromMongo();
    await _notifications.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (details) async {
      final number = details.payload; // This will be the phone number
      if (number != null) {
        // Find contact with this number
        final normalizedNumber = normalizeNumber(number);
        final contact = globalContacts.firstWhere(
          (c) {
            final contactNumber = normalizeNumber(c.phoneNumber);
            return contactNumber == normalizedNumber;
          } ,
          orElse: () => Contact(
            id: '',
            name: 'Unknown Caller',
            phoneNumber: number,
            organization: '',
            position: '',
            starred: 0,
          ),
        );
        
        
        // Use navigatorKey to push ContactDetails
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => Tabs(
              currentIndex: 1, // Index for Contacts tab
              tabs: const ['Tasks', 'Contacts', 'Projects', 'Events'],
              initialContact: contact, // Pass the contact to open
            ),
          ),
        );
        
      }
    },
  );
    listenForCalls(); // Start listening for calls after initialization
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.phone,
      Permission.notification,
    ].request();
  }

  Future<void> showIncomingCallNotification(String? number) async {
    try {
      final normalizedNumber = number != null ? normalizeNumber(number) : '';
      
      // Check if number exists in globalContacts
      final contactExists = globalContacts.any(
        (c) => normalizeNumber(c.phoneNumber) == normalizedNumber
      );
      
      // Only proceed if contact exists
      if (contactExists) {
        final contact = globalContacts.firstWhere(
          (c) => normalizeNumber(c.phoneNumber) == normalizedNumber
        );

        const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
          'call_channel',
          'Incoming Calls',
          channelDescription: 'Notification channel for incoming calls',
          importance: Importance.high,
          priority: Priority.high,
          fullScreenIntent: false,
          category: AndroidNotificationCategory.call,
          ticker: 'Incoming call',
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
          styleInformation: BigTextStyleInformation(''),
        );
        
        final NotificationDetails notificationDetails = 
            NotificationDetails(android: androidDetails);

        await _notifications.show(
          0,
          '${contact.name} is calling you',
          'Click to view contact details',
          notificationDetails,
          payload: contact.phoneNumber,
        );

        print("Notification sent for contact: ${contact.name}");
      } else {
        print("Number not in contacts, skipping notification: $normalizedNumber");
      }
    } catch (e) {
      print("Error showing notification: $e");
    }
  }

  void listenForCalls() {
    PhoneState.stream.listen((PhoneState? event) async {
      if (event != null && event.status == PhoneStateStatus.CALL_INCOMING && userSession.isLoggedIn) {
        final number = event.number;
        print("Incoming call detected from: $number");
        
        // Check if notifications are enabled
        final prefs = await SharedPreferences.getInstance();
        final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        
        if (number != null && notificationsEnabled) {
          showIncomingCallNotification(number);
        } else if (!notificationsEnabled) {
          print("Call notifications are disabled by user");
        }
      }
    });
  }

  Future<void> loadContactsFromMongo() async {
    String userId = UserSession().userId ?? '';
    if (userId.isEmpty) {
      print("No user ID available. Cannot load contacts.");
      globalContacts = [];
      return;
    }

    try {
      // Use ContactsAdapter instead of direct MongoDB access
      List<Map<String, dynamic>> fetchedContacts = await ContactsAdapter.getContacts();
      globalContacts = fetchedContacts.map((doc) => Contact.fromMongo(doc)).toList();
      
      print(
        "Successfully loaded ${globalContacts.length} contacts for notifications",
      );
    } catch (e) {
      print("Error loading contacts for notification: $e");
      globalContacts = [];
    }
  }
}
