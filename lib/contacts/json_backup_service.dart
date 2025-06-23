/*
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class JsonBackupService {
  static const String _contactsFileName = 'contacts_backup.json';

  /// Get the local path where the backup file will be stored
  static Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  /// Get the full path to the backup file
  static Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/$_contactsFileName');
  }

  /// Save contacts data to a JSON file
  static Future<bool> saveContactsBackup(
    List<Map<String, dynamic>> contacts,
  ) async {
    try {
      final file = await _localFile;

      // Add timestamp to the backup
      final backupData = {
        'timestamp': DateTime.now().toIso8601String(),
        'contacts': contacts,
      };

      // Convert the data to JSON and write to file
      final jsonString = jsonEncode(backupData);
      await file.writeAsString(jsonString);

      print('Contacts backup saved successfully at: ${file.path}');
      return true;
    } catch (e) {
      print('Error saving contacts backup: $e');
      return false;
    }
  }

  /// Load contacts data from the backup JSON file
  static Future<List<Map<String, dynamic>>> loadContactsBackup() async {
    try {
      final file = await _localFile;

      // Check if backup file exists
      if (!await file.exists()) {
        print('No backup file found');
        return [];
      }

      // Read the file content
      final jsonString = await file.readAsString();
      final backupData = jsonDecode(jsonString);

      // Extract contacts from the backup
      final List<dynamic> contactsList = backupData['contacts'];

      // Convert to List<Map<String, dynamic>>
      return contactsList
          .map((contact) => Map<String, dynamic>.from(contact))
          .toList();
    } catch (e) {
      print('Error loading contacts backup: $e');
      return [];
    }
  }

  /// Check if a backup file exists
  static Future<bool> backupExists() async {
    final file = await _localFile;
    return file.exists();
  }

  /// Get information about the backup (timestamp, number of contacts)
  static Future<Map<String, dynamic>> getBackupInfo() async {
    try {
      final file = await _localFile;

      if (!await file.exists()) {
        return {'exists': false, 'timestamp': null, 'contactCount': 0};
      }

      final jsonString = await file.readAsString();
      final backupData = jsonDecode(jsonString);

      return {
        'exists': true,
        'timestamp': backupData['timestamp'],
        'contactCount': (backupData['contacts'] as List).length,
      };
    } catch (e) {
      print('Error getting backup info: $e');
      return {'exists': false, 'error': e.toString()};
    }
  }

  /// Compare local backup with MongoDB data and return contacts that need to be synchronized
  static Future<Map<String, List<Map<String, dynamic>>>> compareWithMongoData(
    List<Map<String, dynamic>> mongoContacts,
  ) async {
    final localContacts = await loadContactsBackup();

    // Contacts that exist locally but not in MongoDB (need to be added to MongoDB)
    final List<Map<String, dynamic>> contactsToAdd = [];

    // Contacts that exist in both but might have different data (need to be updated in MongoDB)
    final List<Map<String, dynamic>> contactsToUpdate = [];

    // Check for contacts that are in the local backup but not in MongoDB
    for (var localContact in localContacts) {
      bool foundInMongo = false;

      for (var mongoContact in mongoContacts) {
        // Compare by name, organization, and phone number to identify the same contact
        // This is a fallback for cases where the ObjectId might be different
        if (_isSameContact(localContact, mongoContact)) {
          foundInMongo = true;

          // Check if the contact data differs
          if (!_isIdenticalContact(localContact, mongoContact)) {
            contactsToUpdate.add(localContact);
          }
          break;
        }
      }

      if (!foundInMongo) {
        contactsToAdd.add(localContact);
      }
    }

    return {'toAdd': contactsToAdd, 'toUpdate': contactsToUpdate};
  }

  /// Helper method to determine if two contact records represent the same contact
  static bool _isSameContact(
    Map<String, dynamic> contact1,
    Map<String, dynamic> contact2,
  ) {
    return contact1['name'] == contact2['name'] &&
        contact1['organization'] == contact2['organization'] &&
        contact1['phoneNumber'] == contact2['phoneNumber'];
  }

  /// Helper method to check if two contacts have identical data
  static bool _isIdenticalContact(
    Map<String, dynamic> contact1,
    Map<String, dynamic> contact2,
  ) {
    return contact1['name'] == contact2['name'] &&
        contact1['organization'] == contact2['organization'] &&
        contact1['phoneNumber'] == contact2['phoneNumber'] &&
        contact1['position'] == contact2['position'] &&
        contact1['starred'] == contact2['starred'];
  }
}
*/