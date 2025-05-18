// Using Contact from models/contact.dart instead
import '../models/contact.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

/// Helper class to simplify the integration of the API with the existing code
class ApiIntegrationHelper {
  /// Get the API base URL based on platform
  static String getBaseUrl() {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000/api'; // For Android emulator
    } else {
      return 'http://localhost:3000/api'; // For iOS/web
    }
  }

  /// Fetch contacts from the API and convert to Contact objects
  static Future<List<Contact>> fetchContactsFromApi() async {
    try {
      final response = await http.get(Uri.parse('${getBaseUrl()}/contacts'));

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);

        // Convert API response to local Contact objects
        return jsonData.map((json) {
          // Convert raw JSON directly to Contact objects
          return Contact(
            // Use hash code of ID string as the local integer ID
            id: json['_id'].toString().hashCode,
            name: json['name'] ?? '',
            phoneNumber: json['phoneNumber'] ?? '',
            position: json['position'] ?? '',
            organization: json['organization'] ?? '',
            starred: json['starred'] == true || json['starred'] == 1 ? 1 : 0,
          );
        }).toList();
      } else {
        throw Exception('Failed to load contacts: ${response.statusCode}');
      }
    } catch (e) {
      print('API error in fetchContactsFromApi: $e');
      // Return empty list on error
      return [];
    }
  }

  /// Create a contact via the API
  static Future<bool> createContact(Contact contact) async {
    try {
      final response = await http.post(
        Uri.parse('${getBaseUrl()}/contacts'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': contact.name,
          'phoneNumber': contact.phoneNumber,
          'position': contact.position,
          'organization': contact.organization,
          'starred': contact.starred == 1,
          'type': 'contact',
        }),
      );

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('API error in createContact: $e');
      return false;
    }
  }

  /// Update a contact via the API
  static Future<bool> updateContact(Contact contact) async {
    try {
      final response = await http.put(
        Uri.parse('${getBaseUrl()}/contacts/${contact.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': contact.name,
          'phoneNumber': contact.phoneNumber,
          'position': contact.position,
          'organization': contact.organization,
          'starred': contact.starred == 1,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('API error in updateContact: $e');
      return false;
    }
  }

  /// Update just the starred status of a contact
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

  /// Delete a contact via the API
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
