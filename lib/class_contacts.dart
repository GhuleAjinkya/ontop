// dependancies
import 'dart:io';
import 'mongodb.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'main.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

// Contact Object, will likely modify later
class Contact {
  final int id;
  final String name;
  final String organization;
  final String position;
  final String phoneNumber;
  int starred;

  Contact({
    required this.id,
    required this.name,
    required this.organization,
    required this.phoneNumber,
    required this.position,
    required this.starred,
  });
}

class DBHelper {
  // Class for holding methods with which we'll modify the contactcts database

  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();
  // This just ensures we dont try to open miltiple databases at the same time
  static Database? _database;

  Future<Database> get database async {
    // just checks if the database already exists or needs to be remade
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
    // iF db doesn't exist, create the table
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
    // saves contacts to a var
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'contacts',
      orderBy: 'organization ASC',
    );
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

  Future<void> deleteContact(id) async {
    final db = await database;
    await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
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

class Contacts extends StatefulWidget {
  const Contacts({super.key});

  @override
  State<Contacts> createState() => _ContactsState();
}

class _ContactsState extends State<Contacts> {
  final DBHelper dbHelper = DBHelper(); // initialize dbHelper methods
  // for adding a new contact
  final TextEditingController nameController = TextEditingController();
  final TextEditingController organizationController = TextEditingController();
  final TextEditingController positionController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  List<Contact> contacts = [];
  List<Contact> starred = [];
  Set<int> selectedIDs = {};
  Map<String, List<Contact>> sections = {};
  bool addingContact = false;
  Contact? openedContact;

  // stores data about how individual contacts in the list look like and how they react
  Widget buildContactTiles(
    List<Contact> contacts,
    BuildContext context, {
    bool starred = false,
  }) {
    Icon contactIcon;
    if (starred) {
      contactIcon = Icon(Icons.star_rounded);
    } else {
      contactIcon = Icon(Icons.person);
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      shrinkWrap: true,
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        final isSelected = selectedIDs.contains(contact.id);
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
          child: Container(
            decoration: standardTile(10, isSelected: isSelected),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: ListTile(
              dense: true,
              leading: Icon(
                isSelected ? Icons.check_circle : contactIcon.icon,
                color:
                    isSelected
                        ? Theme.of(context).colorScheme.tertiary
                        : Theme.of(context).colorScheme.onPrimary,
              ),
              title: Text(
                contact.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                '${contact.position}, ${contact.organization}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.tertiary,
                  fontWeight: FontWeight.w400,
                ),
              ),
              onLongPress: () {
                setState(() {
                  if (!isSelected) {
                    selectedIDs.add(contact.id);
                  }
                });
              },
              onTap: () {
                setState(() {
                  if (isSelected) {
                    selectedIDs.remove(contact.id);
                  } else if (selectedIDs.isNotEmpty) {
                    selectedIDs.add(contact.id);
                  } else {
                    openedContact = contact;
                  }
                });
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> begin() async {
    // Fetch contacts from MongoDB instead of SQLite
    try {
      List<Map<String, dynamic>> mongoContacts =
          await MongoDatabase.getContacts();

      // Convert MongoDB documents to Contact objects
      contacts =
          mongoContacts.map((doc) {
            return Contact(
              // MongoDB uses _id which is an ObjectId, convert to int for compatibility
              id: doc['_id'].toString().hashCode,
              name: doc['name'] ?? '',
              organization: doc['organization'] ?? '',
              phoneNumber: doc['phoneNumber'] ?? '',
              position: doc['position'] ?? '',
              starred: doc['starred'] ?? 0,
            );
          }).toList();

      // Original SQLite code (commented out)
      // contacts = await dbHelper.fetchContacts();
    } catch (e) {
      print("Error loading contacts from MongoDB: $e");
      // Fallback to SQLite if MongoDB fails
      contacts = await dbHelper.fetchContacts();
    }

    // Organize in memory
    sections = {
      'A': [],
      'B': [],
      'C': [],
      'D': [],
      'E': [],
      'F': [],
      'G': [],
      'H': [],
      'I': [],
      'J': [],
      'K': [],
      'L': [],
      'M': [],
      'N': [],
      'O': [],
      'P': [],
      'Q': [],
      'R': [],
      'S': [],
      'T': [],
      'U': [],
      'V': [],
      'W': [],
      'X': [],
      'Y': [],
      'Z': [],
    };

    // Sort contacts into sections
    for (var contact in contacts.where((c) => c.starred == 0)) {
      if (contact.name.isNotEmpty) {
        // Check for empty name
        String firstLetter = contact.name[0].toUpperCase();
        if (sections.containsKey(firstLetter)) {
          sections[firstLetter]!.add(contact);
        }
      }
    }

    // Sort each section
    sections.forEach((key, list) {
      if (list.isNotEmpty) {
        // Add this check
        list.sort((a, b) => a.name.compareTo(b.name));
      }
    });

    starred = contacts.where((c) => c.starred == 1).toList();
    if (starred.isNotEmpty) {
      starred.sort((a, b) => a.name.compareTo(b.name));
    }
    setState(() {});
  }

  void clearForm() {
    if (mounted) {
      setState(() {
        addingContact = false;
      });
      nameController.clear();
      organizationController.clear();
      positionController.clear();
      phoneController.clear();
    }
  }

  void starSelected() async {
    for (var id in selectedIDs) {
      var contact = contacts.firstWhere((contact) => contact.id == id);
      contact.starred = 1;
      await dbHelper.updateContact(contact);
    }
    await begin();
  }

  void deStarSelected() async {
    for (var id in selectedIDs) {
      var starredContact = starred.firstWhere((star) => star.id == id);
      starredContact.starred = 0;
      await dbHelper.updateContact(starredContact);
    }
    await begin();
  }

  void deleteSelected() async {
    try {
      // Get MongoDB contacts to find the actual ObjectIds
      List<Map<String, dynamic>> mongoContacts =
          await MongoDatabase.getContacts();

      for (var id in selectedIDs) {
        // Find the MongoDB document that matches this contact's id hash
        var mongoDoc = mongoContacts.firstWhere(
          (doc) => doc['_id'].toString().hashCode == id,
          orElse: () => <String, dynamic>{},
        );

        if (mongoDoc.isNotEmpty) {
          // Delete from MongoDB using the actual ObjectId
          bool success = await MongoDatabase.deleteData(mongoDoc['_id']);

          if (success) {
            print("Contact deleted from MongoDB successfully!");
          } else {
            print("Failed to delete contact from MongoDB");
            // Fallback to SQLite
            await dbHelper.deleteContact(id);
          }
        } else {
          // Contact only exists in SQLite (or not found)
          await dbHelper.deleteContact(id);
        }
      }
      selectedIDs.clear();
      await begin();

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contacts deleted successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print("Error deleting contacts: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error deleting contacts'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Try one more time with SQLite as fallback
      try {
        for (var id in selectedIDs) {
          await dbHelper.deleteContact(id);
        }
        selectedIDs.clear();
        await begin();
      } catch (_) {
        // If even this fails, just clear the UI selection
        selectedIDs.clear();
        setState(() {});
      }
    }
  }

  void selectAll() {
    selectedIDs.addAll(contacts.map((contact) => contact.id));
  }

  bool allAreSelected() {
    return contacts.every((contact) {
      return selectedIDs.contains(contact.id);
    });
  }

  bool allSeletedAreStarred() {
    return selectedIDs.every((id) {
      var contact = contacts.firstWhere((c) => c.id == id);
      return contact.starred == 1;
    });
  }

  Future<void> requestStoragePermission() async {
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      await Permission.manageExternalStorage.request();
    }
  }

  @override
  void initState() {
    super.initState();
    begin();
  }

  @override
  Widget build(BuildContext context) {
    bool allStarred = allSeletedAreStarred();
    bool allSelected = allAreSelected();

    if (openedContact != null) {
      return ContactDetails(
        contact: openedContact!,
        onBack: () async {
          setState(() {
            openedContact = null;
          });

          await begin();
        },
      );
    }
    return Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: Container(
          color: Theme.of(context).colorScheme.primary,
          child: Column(
            children: [
              Container(
                color: Theme.of(context).colorScheme.primary,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        margin: EdgeInsets.only(left: 40),
                        child: Text(
                          'Contacts',
                          style: TextStyle(
                            fontSize: 28,
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (selectedIDs.isEmpty) ...[
                        Container(
                          margin: EdgeInsets.only(right: 20),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.search,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                  size: 30,
                                ),
                                onPressed: () {},
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.add,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                  size: 26,
                                ),
                                onPressed: () {
                                  setState(() {
                                    addingContact = true;
                                  });
                                },
                              ),
                              PopupMenuButton<String>(
                                icon: Icon(
                                  Icons.more_vert,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                  size: 28,
                                ),
                                onSelected: (value) async {
                                  await requestStoragePermission(); // ask for permission first

                                  final downloadsPath =
                                      '/storage/emulated/0/Download/contacts_copy.db';
                                  final dbPath = path.join(
                                    await getDatabasesPath(),
                                    'contacts.db',
                                  );
                                  final downloadsFile = File(downloadsPath);
                                  final dbFile = File(dbPath);

                                  if (value == 'export') {
                                    if (await dbFile.exists()) {
                                      await dbFile.copy(downloadsPath);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Exported successfully!',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  } else if (value == 'import') {
                                    if (await downloadsFile.exists()) {
                                      await downloadsFile.copy(dbPath);
                                      await begin(); // refresh contacts after import
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Imported successfully!',
                                            ),
                                          ),
                                        );
                                      }
                                    } else {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'contacts_copy.db not found in Downloads',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                                itemBuilder:
                                    (context) => [
                                      PopupMenuItem(
                                        value: 'import',
                                        child: Text('Import'),
                                      ),
                                      PopupMenuItem(
                                        value: 'export',
                                        child: Text('Export'),
                                      ),
                                    ],
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          margin: EdgeInsets.only(right: 20),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  // ignore: dead_code
                                  allSelected
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.circle_outlined,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                  size: 30,
                                ),
                                onPressed: () {
                                  setState(() {
                                    if (allSelected) {
                                      selectedIDs.clear();
                                    } else {
                                      selectAll();
                                    }
                                  });
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  // ignore: dead_code
                                  allStarred
                                      ? Icons.star_outline_rounded
                                      : Icons.star_rounded,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                  size: 26,
                                ),
                                onPressed: () {
                                  setState(() {
                                    if (allStarred) {
                                      deStarSelected();
                                    } else {
                                      starSelected();
                                    }
                                  });
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                  size: 28,
                                ),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder:
                                        (context) => AlertDialog(
                                          backgroundColor:
                                              Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            side: BorderSide(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onSecondary,
                                              width: 1.5,
                                            ),
                                          ),
                                          title: Text(
                                            'Delete Contacts?',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onPrimary,
                                            ),
                                          ),
                                          content: Text(
                                            'Selected contacts will be permanently deleted.',
                                            style: TextStyle(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onPrimary,
                                            ),
                                          ),
                                          actions: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceEvenly,
                                              children: [
                                                IconButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        context,
                                                      ),
                                                  icon: Icon(
                                                    Icons.close,
                                                    color:
                                                        Theme.of(
                                                          context,
                                                        ).colorScheme.onPrimary,
                                                    size: 30,
                                                  ),
                                                ),
                                                IconButton(
                                                  onPressed: () {
                                                    deleteSelected();
                                                    Navigator.pop(context);
                                                  },
                                                  icon: Icon(
                                                    Icons.check,
                                                    color:
                                                        Theme.of(
                                                          context,
                                                        ).colorScheme.error,
                                                    size: 30,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (addingContact) ...[
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 36,
                    vertical: 5,
                  ),
                  decoration: standardTile(10),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 2),
                    leading: IconButton(
                      alignment: Alignment.centerLeft,
                      onPressed: clearForm,
                      icon: Icon(
                        Icons.close,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 20,
                      ),
                    ),
                    title: Column(
                      children: [
                        SizedBox(
                          child: TextField(
                            controller: nameController,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                            cursorColor: Theme.of(context).colorScheme.tertiary,
                            decoration: InputDecoration(
                              hintText: 'Name',
                              labelText: 'Name*',
                              labelStyle: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.onSecondary,
                              ),
                              hintStyle: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.onSecondary,
                              ),
                              border: const UnderlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          child: TextField(
                            keyboardType: TextInputType.numberWithOptions(
                              signed: false,
                              decimal: false,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            controller: phoneController,
                            cursorColor: Theme.of(context).colorScheme.tertiary,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Number',
                              labelText: 'Number*',
                              labelStyle: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.onSecondary,
                              ),
                              hintStyle: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.onSecondary,
                              ),
                              border: const UnderlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      children: [
                        SizedBox(
                          child: TextField(
                            controller: positionController,
                            cursorColor: Theme.of(context).colorScheme.tertiary,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Position',
                              labelText: 'Position*',
                              labelStyle: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.onSecondary,
                              ),
                              hintStyle: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.onSecondary,
                              ),
                              border: const UnderlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          child: TextField(
                            controller: organizationController,
                            cursorColor: Theme.of(context).colorScheme.tertiary,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Organization',
                              labelText: 'Organization*',
                              labelStyle: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.onSecondary,
                              ),
                              hintStyle: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.onSecondary,
                              ),
                              border: const UnderlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      alignment: Alignment.centerRight,
                      onPressed: () async {
                        if (nameController.text.trim().isEmpty ||
                            organizationController.text.trim().isEmpty ||
                            phoneController.text.trim().isEmpty ||
                            positionController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'All fields are required',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onError,
                                ),
                              ),
                              backgroundColor:
                                  Theme.of(context).colorScheme.error,
                              duration: Duration(seconds: 2),
                            ),
                          );
                          return;
                        }

                        final newContact = Contact(
                          id: 0,
                          name: nameController.text.trim(),
                          organization: organizationController.text.trim(),
                          phoneNumber: phoneController.text.trim(),
                          position: positionController.text.trim(),
                          starred: 0,
                        );

                        clearForm();

                        // Insert data into MongoDB
                        bool success = await MongoDatabase.insertData({
                          'name': newContact.name,
                          'organization': newContact.organization,
                          'phoneNumber': newContact.phoneNumber,
                          'position': newContact.position,
                          'starred': 0,
                        });

                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Contact added to MongoDB successfully!',
                              ),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          print("Contact successfully added to MongoDB!");
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to add contact to MongoDB'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          print("Failed to add contact to MongoDB");
                        }

                        await begin();
                      },
                      icon: Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
              Expanded(
                child: ListView(
                  children: [
                    if (starred.isNotEmpty) ...[
                      Container(
                        margin: const EdgeInsets.only(left: 40),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 20,
                            ),
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.only(
                                  left: 10,
                                  right: 40,
                                ),
                                height: 5,
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  border: Border(
                                    bottom: BorderSide(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                      width: 0.75,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      buildContactTiles(starred, context, starred: true),
                    ],
                    for (var entry in sections.entries) ...[
                      if (entry.value.isNotEmpty) ...[
                        const Divider(height: 1, color: Colors.transparent),
                        Container(
                          margin: const EdgeInsets.only(left: 40),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                entry.key,
                                style: TextStyle(
                                  fontSize: 16,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                  //fontWeight: FontWeight.bold,
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.only(
                                    left: 10,
                                    right: 40,
                                  ),
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    border: Border(
                                      bottom: BorderSide(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onPrimary,
                                        width: 0.75,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        buildContactTiles(entry.value, context),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ContactDetails extends StatefulWidget {
  const ContactDetails({
    super.key,
    required this.contact,
    required this.onBack,
  });
  final Contact contact;
  final VoidCallback onBack;

  @override
  State<ContactDetails> createState() => _ContactDetailsState();
}

class _ContactDetailsState extends State<ContactDetails> {
  void callNumber(String phoneNumber, VoidCallback onError) async {
    final Uri uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
    onError();
  }

  void openWhatsApp(String phoneNumber, VoidCallback onError) async {
    // Format the number for India (country code +91)
    String formattedNumber = phoneNumber.replaceAll(RegExp(r'\D'), '');

    // Check and adjust formatting for Indian numbers
    if (formattedNumber.length == 10) {
      // It's a 10-digit mobile number without country code
      formattedNumber = '91$formattedNumber';
    } else if (formattedNumber.startsWith('0') &&
        formattedNumber.length == 11) {
      // Number starts with 0 (sometimes people add 0 before mobile number)
      formattedNumber = '91${formattedNumber.substring(1)}';
    } else if (formattedNumber.startsWith('91') &&
        formattedNumber.length == 12) {
      // Already has country code without + sign
      // formattedNumber is already correct
    } else if (formattedNumber.startsWith('+91') ||
        (formattedNumber.startsWith('091'))) {
      // Has +91 or 091 prefix
      // Extract just the last 10 digits and add 91
      String lastTenDigits = formattedNumber.substring(
        formattedNumber.length - 10,
      );
      formattedNumber = '91$lastTenDigits';
    }

    String text = Uri.encodeComponent('');
    final Uri appUri = Uri.parse(
      "whatsapp://send?phone=$formattedNumber&text=$text",
    );

    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri, mode: LaunchMode.externalNonBrowserApplication);
      return;
    }
    final Uri webUri = Uri.parse("https://wa.me/$formattedNumber?text=$text");
    if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
      return;
    }
    onError();
  }

  Widget divLine(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      height: 3,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            width: 0.75,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }

  Widget inputField(
    BuildContext context,
    TextEditingController fieldController,
    String fieldName,
  ) {
    return SizedBox(
      child: TextField(
        cursorColor: Theme.of(context).colorScheme.onPrimary,
        controller: fieldController,
        style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
        decoration: InputDecoration(
          hintText: fieldName,
          labelText: '$fieldName*',
          hintStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSecondary,
          ),
          border: const UnderlineInputBorder(),
        ),
      ),
    );
  }

  bool starred = false;
  bool editingContact = false;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController organizationController = TextEditingController();
  final TextEditingController positionController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final DBHelper dbHelper = DBHelper();
  late Contact localContact;

  @override
  void initState() {
    super.initState();
    localContact = Contact(
      id: widget.contact.id,
      name: widget.contact.name,
      organization: widget.contact.organization,
      position: widget.contact.position,
      phoneNumber: widget.contact.phoneNumber,
      starred: widget.contact.starred,
    );

    nameController.text = localContact.name;
    organizationController.text = localContact.organization;
    positionController.text = localContact.position;
    phoneController.text = localContact.phoneNumber;

    starred = localContact.starred == 1;
  }

  @override
  void dispose() {
    nameController.dispose();
    organizationController.dispose();
    positionController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: EdgeInsets.only(left: 35, bottom: 30, right: 35, top: 60),
            alignment: AlignmentDirectional.topStart,
            decoration: standardTile(40),
            child: Container(
              margin: EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 30),
              child: ListView(
                children: [
                  if (!editingContact) ...[
                    Center(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            localContact.name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 19,
                            ),
                          ),
                          Text(
                            localContact.phoneNumber,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSecondary,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            "${localContact.position}, ${localContact.organization}",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSecondary,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      margin: EdgeInsets.only(bottom: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        spacing: 10,
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() {
                                editingContact = false;
                              });
                              nameController.text = localContact.name;
                              organizationController.text =
                                  localContact.organization;
                              positionController.text = localContact.position;
                              phoneController.text = localContact.phoneNumber;
                            },
                            icon: Icon(
                              Icons.close,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                inputField(context, nameController, "Name"),
                                SizedBox(
                                  child: TextField(
                                    cursorColor:
                                        Theme.of(context).colorScheme.onPrimary,
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                          signed: false,
                                          decimal: false,
                                        ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    controller: phoneController,
                                    style: TextStyle(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                      fontSize: 14,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Number',
                                      labelText: 'Number*',
                                      hintStyle: TextStyle(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSecondary,
                                      ),
                                      border: const UnderlineInputBorder(),
                                    ),
                                  ),
                                ),
                                inputField(
                                  context,
                                  positionController,
                                  "Position",
                                ),
                                inputField(
                                  context,
                                  organizationController,
                                  "Organization",
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              if (nameController.text.trim().isEmpty ||
                                  organizationController.text.trim().isEmpty ||
                                  phoneController.text.trim().isEmpty ||
                                  positionController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'All fields are required',
                                      style: TextStyle(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onError,
                                      ),
                                    ),
                                    backgroundColor:
                                        Theme.of(context).colorScheme.error,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }
                              setState(() {
                                localContact = Contact(
                                  id: localContact.id,
                                  name: nameController.text.trim(),
                                  organization:
                                      organizationController.text.trim(),
                                  phoneNumber: phoneController.text.trim(),
                                  position: positionController.text.trim(),
                                  starred: starred ? 1 : 0,
                                );
                                editingContact = false;
                              });

                              try {
                                // Find the original MongoDB document to get the real ObjectId
                                List<Map<String, dynamic>> mongoContacts =
                                    await MongoDatabase.getContacts();
                                // Find the matching document by comparing fields
                                var mongoDoc = mongoContacts.firstWhere(
                                  (doc) =>
                                      doc['_id'].toString().hashCode ==
                                      localContact.id,
                                  orElse: () => <String, dynamic>{},
                                );

                                // Check if the document ID is a valid mongo ObjectId
                                if (mongoDoc.isNotEmpty &&
                                    mongoDoc['_id'] is! mongo.ObjectId) {
                                  print(
                                    "MongoDB document _id is of type: ${mongoDoc['_id'].runtimeType}",
                                  );
                                }
                                if (mongoDoc.isNotEmpty) {
                                  // Update in MongoDB using the actual ObjectId
                                  bool success = await MongoDatabase.updateData(
                                    {
                                      '_id': mongoDoc['_id'],
                                      'name': localContact.name,
                                      'organization': localContact.organization,
                                      'phoneNumber': localContact.phoneNumber,
                                      'position': localContact.position,
                                      'starred': localContact.starred,
                                    },
                                  );

                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Contact updated successfully!',
                                        ),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Failed to update contact',
                                        ),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                    // Fallback to SQLite if MongoDB fails
                                    await dbHelper.updateContact(localContact);
                                  }
                                }
                              } catch (e) {
                                print("Error updating contact: $e");
                                // Fallback to SQLite if MongoDB update throws an exception
                                await dbHelper.updateContact(localContact);
                              }
                            },

                            icon: Icon(
                              Icons.check,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  divLine(context),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        onPressed: () {
                          callNumber(localContact.phoneNumber, () {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Couldn't open the contact"),
                              ),
                            );
                          });
                        },
                        icon: Icon(
                          Icons.phone_in_talk_outlined,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          openWhatsApp(localContact.phoneNumber, () {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Could not launch WhatsApp"),
                              ),
                            );
                          });
                        },
                        icon: Icon(
                          FontAwesomeIcons.whatsapp,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                  divLine(context),
                  ListTile(
                    // Redo for final
                    title: Text(
                      "Projects",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    subtitle: Text(
                      "No current projects with this contact",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSecondary,
                      ),
                    ),
                  ),
                  divLine(context),
                  ListTile(
                    // Redo for final
                    title: Text(
                      "Notes",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    subtitle: Text(
                      "Store some details regarding this contact",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: -20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.all(20),
                child: Container(
                  padding: EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.onPrimary,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    starred ? Icons.star_rounded : Icons.person_2_outlined,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 60,
                  ),
                ),
              ),
            ),
          ),
          Container(
            margin: EdgeInsets.only(left: 30),
            alignment: Alignment.topLeft,
            child: IconButton(
              onPressed: widget.onBack,
              icon: Icon(
                Icons.arrow_back,
                color: Theme.of(context).colorScheme.onPrimary,
                size: 30,
              ),
            ),
          ),
          Container(
            alignment: Alignment.topRight,
            margin: EdgeInsets.only(right: 30),
            child: Container(
              width: 100,
              height: 50,
              alignment: Alignment.centerRight,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        editingContact = true;
                      });
                    },
                    icon: Icon(
                      editingContact ? Icons.edit : Icons.edit_outlined,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 30,
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      setState(() {
                        starred = !starred;
                        localContact = Contact(
                          id: localContact.id,
                          name: localContact.name,
                          organization: localContact.organization,
                          phoneNumber: localContact.phoneNumber,
                          position: localContact.position,
                          starred: starred ? 1 : 0,
                        );
                      });
                      await dbHelper.updateContact(localContact);
                    },
                    icon: Icon(
                      starred ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
