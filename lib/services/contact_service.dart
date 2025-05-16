import '../models/contact.dart'; // Using canonical Contact class
import 'api_integration_helper.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

// Database helper class to handle local storage
class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      final dbPath = await getDatabasesPath();
      final expectedPath = path.join(dbPath, 'contacts.db');

      if (_database!.path == expectedPath) {
        return _database!;
      }
    }

    _database = await initDatabase();
    return _database!;
  }

  Future<Database> initDatabase() async {
    final dbPath = await getDatabasesPath();
    final dbFilePath = path.join(dbPath, 'contacts.db');
    return await openDatabase(
      dbFilePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE contacts(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            position TEXT NOT NULL,
            organization TEXT NOT NULL,
            phoneNumber TEXT NOT NULL,
            starred INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  Future<int> insertContact(Contact contact) async {
    final db = await database;
    return await db.insert('contacts', {
      'name': contact.name,
      'organization': contact.organization,
      'phoneNumber': contact.phoneNumber,
      'position': contact.position,
      'starred': contact.starred,
    });
  }

  Future<List<Contact>> fetchContacts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('contacts');

    return List.generate(maps.length, (i) {
      return Contact(
        id: maps[i]['id'],
        name: maps[i]['name'],
        organization: maps[i]['organization'],
        phoneNumber: maps[i]['phoneNumber'],
        position: maps[i]['position'],
        starred: maps[i]['starred'],
      );
    });
  }

  Future<int> deleteContact(int id) async {
    final db = await database;
    return await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateContact(Contact contact) async {
    final db = await database;
    return await db.update(
      'contacts',
      {
        'name': contact.name,
        'organization': contact.organization,
        'phoneNumber': contact.phoneNumber,
        'position': contact.position,
        'starred': contact.starred,
      },
      where: 'id = ?',
      whereArgs: [contact.id],
    );
  }
}

class ContactService {
  final DBHelper _dbHelper = DBHelper();

  // Get all contacts from the API
  Future<List<Contact>> fetchContacts() async {
    try {
      // Try to get contacts from API using ApiIntegrationHelper
      final apiContacts = await ApiIntegrationHelper.fetchContactsFromApi();

      if (apiContacts.isNotEmpty) {
        return apiContacts;
      } else {
        throw Exception("No contacts retrieved from API");
      }
    } catch (e) {
      print('Error fetching contacts from API: $e');
      // Fallback to local data if API fails
      return await _dbHelper.fetchContacts();
    }
  }

  // Create a new contact
  Future<bool> createContact(Contact contact) async {
    try {
      // Create contact on API first
      bool success = await ApiIntegrationHelper.createContact(contact);

      if (success) {
        // Then save to local DB as backup
        await _dbHelper.insertContact(contact);
        return true;
      } else {
        throw Exception("API returned unsuccessful status");
      }
    } catch (e) {
      print('Error creating contact on API: $e');
      try {
        // If API fails, still try to save locally
        await _dbHelper.insertContact(contact);
        return true; // Local save successful
      } catch (localError) {
        print('Error saving contact locally: $localError');
        return false; // Failed to save anywhere
      }
    }
  }

  // Update an existing contact
  Future<bool> updateContact(Contact contact) async {
    try {
      // Try API first
      bool success = await ApiIntegrationHelper.updateContact(contact);

      if (success) {
        // Then update local DB as backup
        await _dbHelper.updateContact(contact);
        return true;
      } else {
        throw Exception("API returned unsuccessful status");
      }
    } catch (e) {
      print('Error updating contact on API: $e');
      try {
        // At least try to update locally if API failed
        await _dbHelper.updateContact(contact);
        return true; // Local update successful
      } catch (localError) {
        print('Error updating contact locally: $localError');
        return false; // Failed to update anywhere
      }
    }
  }

  // Delete a contact
  Future<bool> deleteContact(int contactId) async {
    try {
      // Try API first
      bool success = await ApiIntegrationHelper.deleteContact(contactId);

      if (success) {
        // Then delete from local DB
        await _dbHelper.deleteContact(contactId);
        return true;
      } else {
        throw Exception("API returned unsuccessful status");
      }
    } catch (e) {
      print('Error deleting contact from API: $e');
      try {
        // At least try to delete locally if API failed
        await _dbHelper.deleteContact(contactId);
        return true; // Local deletion successful
      } catch (localError) {
        print('Error deleting contact locally: $localError');
        return false; // Failed to delete anywhere
      }
    }
  }

  // Update contact's starred status
  Future<bool> updateStarredStatus(int contactId, bool isStarred) async {
    try {
      // Try API first
      bool success = await ApiIntegrationHelper.updateStarred(
        contactId,
        isStarred,
      );

      if (success) {
        // Then update locally
        var contact = await _getContactById(contactId);
        if (contact != null) {
          contact.starred = isStarred ? 1 : 0;
          await _dbHelper.updateContact(contact);
        }
        return true;
      } else {
        throw Exception("API returned unsuccessful status");
      }
    } catch (e) {
      print('Error updating starred status on API: $e');
      try {
        // Try to update locally
        var contact = await _getContactById(contactId);
        if (contact != null) {
          contact.starred = isStarred ? 1 : 0;
          await _dbHelper.updateContact(contact);
          return true;
        }
        return false;
      } catch (localError) {
        print('Error updating starred status locally: $localError');
        return false;
      }
    }
  }

  // Helper to get a contact by ID
  Future<Contact?> _getContactById(int id) async {
    try {
      final contacts = await _dbHelper.fetchContacts();
      for (var contact in contacts) {
        if (contact.id == id) {
          return contact;
        }
      }
      return null;
    } catch (e) {
      print('Error getting contact by ID: $e');
      return null;
    }
  }
}
