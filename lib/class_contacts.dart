// import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
// import 'package:path_provider/path_provider.dart';

// Contact Object
class Contact {
  final String name;
  final String organization;
  final String phoneNumber;

  Contact({
    required this.name,
    required this.organization, 
    required this.phoneNumber,
  });
}

class DBHelper{
  
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      final dbPath = await getDatabasesPath();
      final expectedPath = join(dbPath, 'contacts.db');
      if (_database!.path == expectedPath) {
        return _database!;
      }
    }
    _database = await initDatabase();
    return _database!;
  }
  Future<Database> initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'contacts.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE contacts(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            organization TEXT,
            phoneNumber TEXT NOT NULL
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
     });
  }
  Future<List<Contact>> fetchContacts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'contacts', orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) {
      return Contact(
        name: maps[i]['name'],
        organization: maps[i]['organization'],
        phoneNumber: maps[i]['phoneNumber'],
      );
    });
  }
  Future<void> deleteContact(id) async{
    final db = await database;
    await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
  } 

}
class Contacts extends StatefulWidget {
  const Contacts({super.key});
  // To-Do Wrap homepage and tabspage icons in HERO widgets to smooth out UI
  // Understand backend
  
  @override
  State<Contacts> createState() => _ContactsState();
}
class _ContactsState extends State<Contacts> {
  final DBHelper dbHelper = DBHelper();
  List<Contact> contacts = [];

  Future<void> begin() async {
    contacts = await dbHelper.fetchContacts();
    setState(() {});
  }

  Future<void> addDummy() async {
    final newContact = Contact(
      name: 'John Doe',
      organization: 'Example Corp',
      phoneNumber: '123-456-7890',
    );
    await dbHelper.insertContact(newContact);
    await begin();
  }
  @override
  void initState() {
    super.initState();
    begin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.miniCenterFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: addDummy,
        backgroundColor: Colors.orange,
        child: Icon(Icons.add),
      ),
      body: Center(
        child: ListView.builder(
          itemCount: contacts.length,
          itemBuilder: (context,index) {
            final contact = contacts[index];
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.orange[400],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  tileColor: Colors.orange,
                  title: Text(contact.name),
                  subtitle: Text(contact.organization),
                  trailing: Text(contact.phoneNumber),
                ),
                
              ),
            );
          },
        ),
      ),
    );
  }
}