import '../../models/contact.dart'; // This is the canonical Contact class
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

// Direct API connector for HTTP requests to the backend API
class ContactApiDirect {
  // Base URL for API requests based on platform
  static String getBaseUrl() {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000/api'; // For Android emulator
    } else {
      return 'http://localhost:3000/api'; // For iOS/web
    }
  }

  // Get all contacts from the API
  static Future<List<Contact>> getContacts() async {
    try {
      final response = await http.get(Uri.parse('${getBaseUrl()}/contacts'));

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        // Convert API response to local Contact objects
        return jsonData.map((json) {
          // Create a proper ApiContact object first
          final apiContact = ApiContact.fromJson(json);
          // Convert to local Contact with a consistent ID
          return Contact(
            // Use hash code of ID string as the local integer ID
            id:
                apiContact.id != null
                    ? apiContact.id.toString().hashCode
                    : DateTime.now().millisecondsSinceEpoch,
            name: apiContact.name,
            phoneNumber: apiContact.phoneNumber,
            position: apiContact.position,
            organization: apiContact.organization,
            starred: apiContact.starred ? 1 : 0,
          );
        }).toList();
      } else {
        throw Exception('Failed to load contacts: ${response.statusCode}');
      }
    } catch (e) {
      print('API error in getContacts: $e');
      // Return empty list on error
      return [];
    }
  }

  // Create a new contact
  static Future<bool> createContact(Contact contact) async {
    try {
      // Convert Contact to ApiContact format
      final apiContact = ApiContact(
        name: contact.name,
        phoneNumber: contact.phoneNumber,
        position: contact.position,
        organization: contact.organization,
        starred: contact.starred == 1,
        type: 'contact',
      );

      final response = await http.post(
        Uri.parse('${getBaseUrl()}/contacts'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(apiContact.toJson()),
      );

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('API error in createContact: $e');
      return false;
    }
  }

  // Update an existing contact
  static Future<bool> updateContact(Contact contact) async {
    try {
      // Convert Contact to ApiContact format
      final apiContact = ApiContact(
        name: contact.name,
        phoneNumber: contact.phoneNumber,
        position: contact.position,
        organization: contact.organization,
        starred: contact.starred == 1,
      );

      final response = await http.put(
        Uri.parse('${getBaseUrl()}/contacts/${contact.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(apiContact.toJson()),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('API error in updateContact: $e');
      return false;
    }
  }

  // Update just the starred status of a contact
  static Future<bool> updateStarred(int contactId, bool isStarred) async {
    try {
      final response = await http.put(
        Uri.parse('${getBaseUrl()}/contacts/$contactId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'starred': isStarred}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('API error in updateStarred: $e');
      return false;
    }
  }

  // Delete a contact
  static Future<bool> deleteContact(int contactId) async {
    try {
      final response = await http.delete(
        Uri.parse('${getBaseUrl()}/contacts/$contactId'),
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('API error in deleteContact: $e');
      return false;
    }
  }
}
