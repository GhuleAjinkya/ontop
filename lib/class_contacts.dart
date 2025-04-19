import 'dart:math';

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
Widget buildContactTiles(List<Contact> contacts, BuildContext context, {bool starred = false}) {
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
            leading: Icon(
              contactIcon.icon,
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
  );
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
  
  @override
  State<Contacts> createState() => _ContactsState();
}
class _ContactsState extends State<Contacts> {
  final DBHelper dbHelper = DBHelper();
  List<Contact> contacts = [];
  List<Contact> starred = [];
  Map<String, List<Contact>> sections = {};

  Future<void> begin() async { // just connect db to local variable
    contacts = await dbHelper.fetchContacts();
    
    // Organize in memory
    sections = {
      'A': [], 'B': [], 'C': [], 'D': [], 'E': [], 'F': [], 'G': [], 'H': [],
      'I': [], 'J': [], 'K': [], 'L': [], 'M': [], 'N': [], 'O': [], 'P': [],
      'Q': [], 'R': [], 'S': [], 'T': [], 'U': [], 'V': [], 'W': [], 'X': [],
      'Y': [], 'Z': [],
    };

    // Sort contacts into sections
    for (var contact in contacts.where((c) => c.starred == 0)) {
      String key = contact.name[0].toUpperCase();
      sections[key]!.add(contact);
    }

    // Sort each section
    sections.forEach((key, list) {
        list.sort((a, b) => a.name.compareTo(b.name));
    });

    starred = contacts.where((c) => c.starred == 1).toList();
    setState(() {});
  }

  Future<void> addDummy() async { // dummy contacts for testing
    final newContact = Contact(
      id: 0,
      name: 'John Doe',
      organization: 'A Example Corp',
      phoneNumber: '123-456-7890',
      position: 'Example Position',
      starred: Random().nextInt(2),
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
      //floatingActionButtonLocation: FloatingActionButtonLocation.miniCenterFloat,
      //floatingActionButton: FloatingActionButton(
        //onPressed: addDummy, // currently calls dummy, will class
        //backgroundColor: Theme.of(context).colorScheme.tertiary,
       // child: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary,),
      //),
      body: Column(
          children: [
            Padding(
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
                  Container(
                    margin: EdgeInsets.only(right: 20),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.search, 
                            color: Theme.of(context).colorScheme.onPrimary,
                            size: 30,
                          ),
                          onPressed: () {
                            
                          }
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.add_call, 
                            color: Theme.of(context).colorScheme.onPrimary,
                            size: 26,
                          ),
                          onPressed: () {
                            addDummy(); // currently calls dummy
                          }
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.more_vert, 
                            color: Theme.of(context).colorScheme.onPrimary,
                            size: 28,
                          ),
                          onPressed: () {                            
                          }
                        ),
                      ],
                    ),
                  ),                  
                ],),
            ),
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
                              margin: const EdgeInsets.only(left: 10, right: 40),
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                border: Border(
                                  bottom: BorderSide(
                                    color: Theme.of(context).colorScheme.onPrimary,
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
                    const Divider(
                      height: 1,
                      color: Colors.transparent,
                    ),
                    if (entry.value.isNotEmpty) ...[
                      Container(
                        margin: const EdgeInsets.only(left: 40),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.sort_by_alpha, // Placeholder icon
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 20,
                            ),
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.only(left: 10, right: 40),
                                height: 5,
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Theme.of(context).colorScheme.onPrimary,
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
      );
  }
}