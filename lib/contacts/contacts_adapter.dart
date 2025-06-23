import 'dart:convert';
import '../shared/mongodb.dart';
import '../shared/user_session.dart';
import '../shared/node_js_api.dart';
import '../notifications/call_notifs/call_notifications.dart';

// Contacts adapter service that works with both Node.js API and direct MongoDB
class ContactsAdapter {
  // Flag to enable/disable Node.js API (fallback to MongoDB if false or on error)
  static bool useNodeJsApi = true;
  static final callService = CallNotificationService();
  // Get all contacts for the current user
  static Future<List<Map<String, dynamic>>> getContacts() async {
    final userId = UserSession().userId;
    if (userId == null) return [];

    if (useNodeJsApi) {
      try {
        // Try Node.js API first
        final response = await NodeJsApi.get('/api/contacts');

        if (response['success']) {
          return List<Map<String, dynamic>>.from(response['data']);
        }
      } catch (e) {
        print('Error fetching contacts from Node.js API: $e');
        // Continue to MongoDB fallback
      }
    }

    // Fallback to MongoDB
    return await MongoDatabase.getContacts(userId: userId, type: 'contact');
  }

  // Add a new contact
  static Future<bool> addContact(Map<String, dynamic> contactData) async {
    final userId = UserSession().userId;
    if (userId == null) return false;

    // Ensure type and timestamp fields are present
    contactData['type'] = 'contact';
    contactData['created_at'] = DateTime.now().toIso8601String();

    if (useNodeJsApi) {
      try {
        // Try Node.js API first
        final response = await NodeJsApi.post('/api/contacts', contactData);
        if (response['success']) {
          await callService.updateContacts();
          print("callService.updateContacts called");
          return true;
        }
      } catch (e) {
        print('Error adding contact via Node.js API: $e');
        // Continue to MongoDB fallback
      }
    }

    // Fallback to MongoDB
    return await MongoDatabase.insertData(
      contactData,
      userId: userId,
      type: 'contact',
    );
  }

  // Update an existing contact
  static Future<bool> updateContact(Map<String, dynamic> contactData) async {
    final userId = UserSession().userId;
    if (userId == null) return false;

    // Ensure contact has the necessary type field
    contactData['type'] = 'contact';

    if (useNodeJsApi) {
      try {
        // Try Node.js API first
        final contactId = contactData['_id'].toString();
        final response = await NodeJsApi.put(
          '/api/contacts/$contactId',
          contactData,
        );
        if (response['success']) {
          await callService.updateContacts();
          print("callService.updateContacts called");
          return true;
        } 
      } catch (e) {
        print('Error updating contact via Node.js API: $e');
        // Continue to MongoDB fallback
      }
    }

    // Fallback to MongoDB
    return await MongoDatabase.updateData(
      contactData,
      userId: userId,
      type: 'contact',
    );
  }

  // Delete a contact
  static Future<bool> deleteContact(dynamic contactId) async {
    print("🟡 DEBUG ContactsAdapter.deleteContact: Starting with ID: $contactId (Type: ${contactId.runtimeType})");
    
    final userId = UserSession().userId;
    if (userId == null) {
      print("🟡 DEBUG ContactsAdapter.deleteContact: No userId available");
      return false;
    }
    
    print("🟡 DEBUG ContactsAdapter.deleteContact: userId = $userId, useNodeJsApi = $useNodeJsApi");

    if (useNodeJsApi) {
      try {
        print("🟡 DEBUG ContactsAdapter.deleteContact: Trying Node.js API first");
        // Try Node.js API first
        final response = await NodeJsApi.delete(
          '/api/contacts/${contactId.toString()}',
        );
        if (response['success']) {
          await callService.updateContacts();
          print("callService.updateContacts called");
          return true;
        }
      } catch (e) {
        print('🟡 DEBUG ContactsAdapter.deleteContact: Error deleting contact via Node.js API: $e');
        // Continue to MongoDB fallback
      }
    }

    // Fallback to MongoDB
    print("🟡 DEBUG ContactsAdapter.deleteContact: Falling back to MongoDB");
    final result = await MongoDatabase.deleteData(contactId, userId: userId);
    print("🟡 DEBUG ContactsAdapter.deleteContact: MongoDB result: $result");
    return result;
  }

  // Toggle star status for a contact
  static Future<bool> toggleStarContact(dynamic contactId, bool starred) async {
    final userId = UserSession().userId;
    if (userId == null) return false;

    if (useNodeJsApi) {
      try {
        // Try Node.js API first
        final starData = {'starred': starred ? 1 : 0};
        final response = await NodeJsApi.put(
          '/api/contacts/${contactId.toString()}/star',
          starData,
        );
        if (response['success']) return true;
      } catch (e) {
        print('Error toggling contact star via Node.js API: $e');
        // Continue to MongoDB fallback
      }
    }

    // Fallback to MongoDB
    return await MongoDatabase.toggleStarContact(
      contactId,
      starred,
      userId: userId,
    );
  }

  // Import multiple contacts
  static Future<bool> importContacts(
    List<Map<String, dynamic>> contacts,
  ) async {
    final userId = UserSession().userId;
    if (userId == null) return false;

    // Ensure all contacts have type field
    for (var contact in contacts) {
      contact['type'] = 'contact';
    }

    if (useNodeJsApi) {
      try {
        // Try Node.js API first
        final importData = {'contacts': contacts};
        final response = await NodeJsApi.post(
          '/api/contacts/import',
          importData,
        );
        if (response['success']) {
          await callService.updateContacts();
          print("callService.updateContacts called");
          return true;
        }
      } catch (e) {
        print('Error importing contacts via Node.js API: $e');
        // Continue to MongoDB fallback
      }
    }

    // Fallback to MongoDB
    return await MongoDatabase.insertMany(
      contacts,
      userId: userId,
      type: 'contact',
    );
  }

  // Export contacts as JSON string
  static Future<String?> exportContactsAsJson() async {
    final contacts = await getContacts();
    if (contacts.isEmpty) return null;

    return jsonEncode(contacts);
  }
}
