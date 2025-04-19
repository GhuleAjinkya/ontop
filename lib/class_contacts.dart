import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'main.dart';

// Contact Object, will likely modify later
class Contact {
  final int id;
  final String name;
  final String organization;
  final String position;
  final String phoneNumber;
  final int starred;

  Contact({
    required this.id,
    required this.name,
    required this.organization, 
    required this.phoneNumber,
    required this.position, 
    required this.starred,
  });
}

class DBHelper{ // Class for holding methods with which we'll modify the contactcts database
  
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();
  // This just ensures we dont try to open miltiple databases at the same time
  // idk how this works tho lol
  static Database? _database;

  Future<Database> get database async { // just checks if the database already exists or needs to be remade
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
  Future<Database> initDatabase() async { // iF db doesn't exist, create the table
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
            position TEXT,
            organization TEXT,
            phoneNumber TEXT NOT NULL,
            starred INTEGER DEFAULT 0
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
    final List<Map<String, dynamic>> maps = await db.query(
      'contacts', orderBy: 'organization ASC',
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
  List<Contact> starred = [];

  Future<void> begin() async { // just connect db to local variable
    contacts = await dbHelper.fetchContacts();
    starred = contacts.where((contact) => contact.starred == 1).toList();
    setState(() {});
  }

  Future<void> addDummy() async { // dummy contacts for testing
    final newContact = Contact(
      id: 0,
      name: 'John Doe',
      organization: 'Example Corp',
      phoneNumber: '123-456-7890',
      position: 'Example Position',
      starred: 0,
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
      backgroundColor: Theme.of(context).colorScheme.primary,
      floatingActionButtonLocation: FloatingActionButtonLocation.miniCenterFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: addDummy, // currently calls dummy, will class
        backgroundColor: Theme.of(context).colorScheme.tertiary,
        child: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary,),
      ),
      body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 20),
                    child: IconButton(
                      icon: Icon(
                        Icons.search, 
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 28,
                      ),
                      onPressed: () {
                        // Search Goes here
                      }
                    ),
                  ),
                  Text(
                    'Contacts',
                    style: TextStyle(
                      fontSize: 28,
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                ],),
            ),
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                shrinkWrap: true,
                itemCount: contacts.length,
                itemBuilder: (context,index) {
                  final name = contacts[index].name;
                  final position = contacts[index].position;
                  final organization = contacts[index].organization;
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
                    child: Container(
                      decoration: standardTile(10),
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      child: ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        leading: Icon(
                          Icons.person, 
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '$position, $organization',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.tertiary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          ),
      );
  }
}