import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../contacts/contact_model.dart' as app_contacts;

class PhoneContactsService {
  /// Request permission to access contacts
  static Future<bool> requestContactsPermission() async {
    // Use permission_handler with array format for reliable permission requests
    final statuses = await [
      Permission.contacts,
    ].request();
    
    return statuses[Permission.contacts] == PermissionStatus.granted;
  }

  /// Check if contacts permission is already granted
  static Future<bool> hasContactsPermission() async {
    // Use permission_handler to check status
    final status = await Permission.contacts.status;
    if (status == PermissionStatus.granted) {
      return true;
    }
    
    // Double-check by trying to access contacts
    try {
      await FlutterContacts.getContacts(
        withProperties: false,
        withThumbnail: false,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Fetch all contacts from the phone
  static Future<List<Contact>> getAllPhoneContacts() async {
    try {
      // First, try to check if we already have permission
      bool canAccessContacts = false;
      try {
        await FlutterContacts.getContacts(
          withProperties: false,
          withThumbnail: false,
        );
        canAccessContacts = true;
        print('✓ Already have contacts permission');
      } catch (e) {
        print('✗ Don\'t have contacts permission yet: $e');
      }

      // If we don't have permission, request it explicitly
      if (!canAccessContacts) {
        print('Requesting contacts permission...');
        
        // Use permission_handler with array format for reliable permission request
        final statuses = await [
          Permission.contacts,
        ].request();
        
        final status = statuses[Permission.contacts];
        print('Permission request status: $status');
        
        if (status == PermissionStatus.granted) {
          print('✓ Permission granted successfully');
        } else if (status == PermissionStatus.denied) {
          throw Exception('Contacts permission was denied. Please try again or grant permission manually in settings.');
        } else if (status == PermissionStatus.permanentlyDenied) {
          throw Exception('Contacts permission was permanently denied. Please enable it in your device settings.');
        } else {
          throw Exception('Unable to get contacts permission. Status: $status');
        }
        
        // Give a moment for the permission to be processed
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Now fetch contacts with full properties
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withThumbnail: false,
        withPhoto: false,
      );

      print('Found ${contacts.length} contacts on device');
      
      // Filter out contacts without names or phone numbers
      final validContacts = contacts.where((contact) {
        return contact.displayName.isNotEmpty || 
               contact.name.first.isNotEmpty || 
               contact.name.last.isNotEmpty ||
               contact.phones.isNotEmpty;
      }).toList();
      
      print('Found ${validContacts.length} valid contacts after filtering');
      return validContacts;
    } catch (e) {
      print('Error fetching phone contacts: $e');
      
      // If we get a permission-related error, provide helpful message
      if (e.toString().toLowerCase().contains('permission') || 
          e.toString().toLowerCase().contains('denied')) {
        throw Exception('Contacts permission denied. Please grant permission in your device settings and restart the app.');
      }
      
      rethrow;
    }
  }

  /// Convert phone contact to app contact with default placeholder values
  static app_contacts.Contact convertToAppContact(Contact phoneContact, int index) {
    // Extract phone number (use first one if multiple)
    String phoneNumber = '';
    if (phoneContact.phones.isNotEmpty) {
      phoneNumber = phoneContact.phones.first.number;
      // Clean phone number but keep the + for international numbers
      phoneNumber = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)\.#]'), '');
    }

    // Extract name (use display name or construct from given/family name)
    String name = phoneContact.displayName.trim();
    if (name.isEmpty) {
      // Try to build name from first and last name
      final firstName = phoneContact.name.first.trim();
      final lastName = phoneContact.name.last.trim();
      if (firstName.isNotEmpty || lastName.isNotEmpty) {
        name = '$firstName $lastName'.trim();
      }
    }

    // If still empty, use phone number as name
    if (name.isEmpty && phoneNumber.isNotEmpty) {
      name = phoneNumber;
    }

    // If still empty, use a default name
    if (name.isEmpty) {
      name = 'Unknown Contact ${index + 1}';
    }

    // Allow contacts without phone numbers but with names
    if (phoneNumber.isEmpty && name == 'Unknown Contact ${index + 1}') {
      throw Exception('Contact has no name or phone number');
    }

    print('Converting contact: $name - $phoneNumber');

    // Generate a more unique ID using contact properties
    final uniqueId = 'import_${DateTime.now().millisecondsSinceEpoch}_${phoneContact.id}_$index';

    return app_contacts.Contact(
      id: uniqueId,
      name: name,
      phoneNumber: phoneNumber.isEmpty ? 'No Phone' : phoneNumber,
      position: 'Unknown', // Default placeholder
      organization: 'Personal', // Default placeholder for personal contacts
      starred: 0,
    );
  }

  /// Get filtered and converted contacts suitable for import
  static Future<List<app_contacts.Contact>> getImportableContacts() async {
    try {
      print('Starting to fetch phone contacts...');
      final phoneContacts = await getAllPhoneContacts();
      print('Fetched ${phoneContacts.length} phone contacts');

      final List<app_contacts.Contact> importableContacts = [];
      int skippedCount = 0;

      for (int i = 0; i < phoneContacts.length; i++) {
        final phoneContact = phoneContacts[i];
        try {
          final appContact = convertToAppContact(phoneContact, i);
          importableContacts.add(appContact);
        } catch (e) {
          // Skip contacts that can't be converted
          skippedCount++;
          print('Skipping contact ${i + 1}: $e');
          continue;
        }
      }

      print(
        'Successfully converted ${importableContacts.length} contacts, skipped $skippedCount',
      );

      // Sort by name, but put contacts with phone numbers first
      importableContacts.sort((a, b) {
        // Contacts with phone numbers come first
        if (a.phoneNumber != 'No Phone' && b.phoneNumber == 'No Phone') {
          return -1;
        } else if (a.phoneNumber == 'No Phone' && b.phoneNumber != 'No Phone') {
          return 1;
        }
        // Then sort alphabetically by name
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      return importableContacts;
    } catch (e) {
      print('Error getting importable contacts: $e');
      rethrow;
    }
  }
}
