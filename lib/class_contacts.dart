// dependancies
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'main.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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

class DBHelper{ // Class for holding methods with which we'll modify the contactcts database
  
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();
  // This just ensures we dont try to open miltiple databases at the same time
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

  Future<List<Contact>> fetchContacts() async { // saves contacts to a var
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
                color: isSelected ? Theme.of(context).colorScheme.tertiary: Theme.of(context).colorScheme.onPrimary,
              ),
              title: Text(
                contact.name,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                '${contact.position}, ${contact.organization}',
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
                  }
                  else  if (selectedIDs.isNotEmpty){
                    selectedIDs.add(contact.id);
                  }
                  else {
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
      if (contact.name.isNotEmpty) {  // Check for empty name
        String firstLetter = contact.name[0].toUpperCase();
        if (sections.containsKey(firstLetter)) {
          sections[firstLetter]!.add(contact);
        }
      }
    }

    // Sort each section
    sections.forEach((key, list) {
        if (list.isNotEmpty) {  // Add this check
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
      // Find the contact with matching ID
      var contact = contacts.firstWhere((contact) => contact.id == id);
      contact.starred = 1;
      await dbHelper.insertContact(contact);
    }
    await begin();
  }

  void deStarSelected() async {
    for (var id in selectedIDs) {
      // Find the contact with matching ID
      var starredContact = starred.firstWhere((star) => star.id == id);
      starredContact.starred = 0;
      await dbHelper.insertContact(starredContact);
    }
    await begin();
  }

  void deleteSelected() async {
    for (var id in selectedIDs) {
      await dbHelper.deleteContact(id);
    }
    selectedIDs.clear();
    await begin();
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
  
  @override
  void initState() {
    super.initState();
    begin(); 
  }

  @override
  Widget build(BuildContext context) {
    
    bool allStarred = allSeletedAreStarred(); // Moved to the State class to persist its value
    bool allSelected = allAreSelected();
    int starredValue = 0;
    if (openedContact != null) {
      return ContactDetails(
        contact: openedContact!, 
        onBack: () => setState(() {
          openedContact = null;
        })
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
                                color: Theme.of(context).colorScheme.onPrimary,
                                size: 30,
                              ),
                              onPressed: () {
                                
                              }
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.add, 
                                color: Theme.of(context).colorScheme.onPrimary,
                                size: 26,
                              ),
                              onPressed: () {
                                setState(() {
                                  addingContact = true;
                                });
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
                      ]
                      else ...[
                        Container(
                          margin: EdgeInsets.only(right: 20),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  // ignore: dead_code
                                  allSelected ? Icons.check_circle_outline_rounded : Icons.circle_outlined, 
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  size: 30,
                                ),
                                onPressed: () {
                                  setState(() {
                                    if(allSelected) {
                                      selectedIDs.clear();
                                    }
                                    else {
                                      selectAll();
                                    }
                                  });
                                }
                              ),
                              IconButton(
                                icon: Icon(
                                  // ignore: dead_code
                                  allStarred ? Icons.star_outline_rounded : Icons.star_rounded, 
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  size: 26,
                                ),
                                onPressed: () {
                                  setState(() {
                                    if (allStarred) {
                                      deStarSelected();
                                    }
                                    else {
                                      starSelected();
                                    }
                                    deleteSelected();
                                  });
                                }
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline_rounded, 
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  size: 28,
                                ),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: Theme.of(context).colorScheme.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        side: BorderSide(
                                          color: Theme.of(context).colorScheme.onSecondary,
                                          width: 1.5,
                                        )
                                      ),
                                      title: Text(
                                        'Delete Contacts?',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimary),
                                      ),
                                      content: Text(
                                        'Selected contacts will be permanently deleted.',
                                        style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                                      ),
                                      actions: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                          children: [
                                            IconButton(
                                              onPressed: () => Navigator.pop(context),
                                              icon: Icon(
                                                Icons.close,
                                                color: Theme.of(context).colorScheme.onPrimary,
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
                                                color: Theme.of(context).colorScheme.error,
                                                size: 30,
                                              ),
                                            )
                                          ],
                                        ),
                                        
                                      ],
                                    ),
                                  );
                                }
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
                  margin: const EdgeInsets.symmetric(horizontal: 36, vertical: 5),
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
                            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary,),
                            decoration: InputDecoration(
                              hintText: 'Name',
                              labelText: 'Name*',
                              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSecondary),
                              border: const UnderlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          child: TextField(
                            keyboardType: TextInputType.numberWithOptions(signed: false, decimal: false),
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            controller: phoneController,
                            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Number',
                              labelText: 'Number*',
                              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSecondary),
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
                            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary,),
                            decoration: InputDecoration(
                              hintText: 'Position',
                              labelText: 'Position*',
                              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSecondary),
                              border: const UnderlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          child: TextField(
                            controller: organizationController,
                            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary,),
                            decoration: InputDecoration(
                              hintText: 'Organization',
                              labelText: 'Organization*',
                              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSecondary),
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
                              content: Text('All fields are required',
                                style: TextStyle(color: Theme.of(context).colorScheme.onError),
                              ),
                              backgroundColor: Theme.of(context).colorScheme.error,
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
                          starred: starredValue,
                        );

                        clearForm();
                        await dbHelper.insertContact(newContact);
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
                      if (entry.value.isNotEmpty) ...[
                        const Divider(
                          height: 1,
                          color: Colors.transparent,
                        ),
                        Container(                           
                          margin: const EdgeInsets.only(left: 40),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                entry.key,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  //fontWeight: FontWeight.bold,
                                ),
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
        ),
      ),    
    );
  }
}

class ContactDetails extends StatefulWidget {
  const ContactDetails({super.key, required this.contact, required this.onBack});
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
    } else if (formattedNumber.startsWith('0') && formattedNumber.length == 11) {
      // Number starts with 0 (sometimes people add 0 before mobile number)
      formattedNumber = '91${formattedNumber.substring(1)}';
    } else if (formattedNumber.startsWith('91') && formattedNumber.length == 12) {
      // Already has country code without + sign
      // formattedNumber is already correct
    } else if (formattedNumber.startsWith('+91') || (formattedNumber.startsWith('091'))) {
      // Has +91 or 091 prefix
      // Extract just the last 10 digits and add 91
      String lastTenDigits = formattedNumber.substring(formattedNumber.length - 10);
      formattedNumber = '91$lastTenDigits';
    }
    
    String text = Uri.encodeComponent('');
    final Uri appUri = Uri.parse("whatsapp://send?phone=$formattedNumber&text=$text");
    
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
          )
        )
      ),
    );
  }

  bool starred = false;
  bool editingContact = false;
  
  @override
  Widget build(BuildContext context) {
    if (widget.contact.starred == 1) {
      starred = true;
    }
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
                  Center(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          widget.contact.name,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 19,
                          ),
                        ),
                        Text(
                          widget.contact.phoneNumber,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSecondary,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          "${widget.contact.position}, ${widget.contact.organization}",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSecondary,
                            fontSize: 17,
                          ),
                        ),
                      ],  
                    ),
                  ),
                  divLine(context),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        onPressed: (){ callNumber(widget.contact.phoneNumber, () {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Couldn't open the contact"))
                            );
                          });
                        },
                        icon: Icon(
                          Icons.phone_in_talk_outlined,
                          color: Theme.of(context).colorScheme.onPrimary,
                        )
                      ),
                      IconButton(
                        onPressed: () {
                          openWhatsApp(widget.contact.phoneNumber, () {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Could not launch WhatsApp")),
                            );
                          });
                        },
                        icon: Icon(
                          FontAwesomeIcons.whatsapp,
                          color: Theme.of(context).colorScheme.onPrimary,
                        )
                      )
                    ],
                  ),
                  divLine(context),
                  ListTile( // Redo for final 
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
                      )
                    ),
                  ),
                  divLine(context),
                  ListTile( // Redo for final 
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
                      )
                    ),
                  ),
                ],
              )
            )
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
                      width: 1.5
                    )
                  ),
                  child: Icon(
                    starred ? Icons.star_rounded : Icons.person_2_outlined,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 60,
                  ),
                ),
              ),
            )
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
              )
            ),
          )
        ],
      ),
    );
  }
}
