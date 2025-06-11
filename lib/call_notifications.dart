import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:phone_state/phone_state.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/contacts_adapter.dart';
import 'user_session.dart';
import 'class_contacts.dart';
import 'package:flutter/material.dart';
import 'main.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class CallNotificationService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  List<Contact> globalContacts = [];

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
        final contact = globalContacts.firstWhere(
          (c) => c.phoneNumber == number,
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
      final normalizedNumber = number?.replaceFirst('+91', '').trim();
      // Try to find contact, use default values if not found
      final contact = globalContacts.firstWhere(
        (c) => c.phoneNumber == normalizedNumber,
        orElse: () => Contact(
          id: '',
          name: 'Unknown Caller',
          phoneNumber: normalizedNumber ?? 'No Number',
          organization: '',
          position: '',
          starred: 0,
        ),
      );

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'call_channel',
        'Incoming Calls',
        channelDescription: 'Notification channel for incoming calls',
        importance: Importance.max,
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

      final title = contact.name != 'Unknown Caller' 
          ? '${contact.name} is calling you'
          : 'Incoming Call: ${normalizedNumber ?? "Unknown Number"}';

      final body = contact.name != 'Unknown Caller'
          ? 'Click to view contact details'
          : 'Unknown caller';

      await _notifications.show(
        0,
        title,
        body,
        notificationDetails,
        payload: contact.phoneNumber,
      );

      print("Notification sent for call from: ${contact.name}");
    } catch (e) {
      print("Error showing notification: $e");
    }
  }

  void listenForCalls() {
    PhoneState.stream.listen((PhoneState? event) {
      if (event != null && event.status == PhoneStateStatus.CALL_INCOMING && userSession.isLoggedIn) {
        final number = event.number;
        print("Incoming call detected from: $number");
        if (number != null) {
          showIncomingCallNotification(number);
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

