// dependencies
import 'dart:io';
import 'dart:convert'; // For JSON encoding/decoding
import 'user_session.dart';
import 'services/contacts_adapter.dart'; // Add our new adapter
import 'services/optimistic_updates.dart'; // Add optimistic updates

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'main.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

// Contact Object for MongoDB data
class Contact {
  final dynamic id; // Can be ObjectId or its string representation
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

  // Convert MongoDB document to Contact object
  factory Contact.fromMongo(Map<String, dynamic> doc) {
    return Contact(
      id: doc['_id'], // Keep as ObjectId
      name: doc['name'] ?? '',
      organization: doc['organization'] ?? '',
      phoneNumber: doc['phoneNumber'] ?? '',
      position: doc['position'] ?? '',
      starred: doc['starred'] ?? 0,
    );
  }

  // Create a copy of Contact with updated values
  Contact copyWith({
    dynamic id,
    String? name,
    String? organization,
    String? position,
    String? phoneNumber,
    int? starred,
  }) {
    return Contact(
      id: id ?? this.id,
      name: name ?? this.name,
      organization: organization ?? this.organization,
      position: position ?? this.position,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      starred: starred ?? this.starred,
    );
  }

  // Convert Contact to Map for MongoDB
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'organization': organization,
      'phoneNumber': phoneNumber,
      'position': position,
      'starred': starred,
      'type': 'contact', // Add type field
    };
  }
}

class Contacts extends StatefulWidget {
  const Contacts({super.key, this.contactToOpen});

  final Contact? contactToOpen;
  @override
  State<Contacts> createState() => _ContactsState();
}

class _ContactsState extends State<Contacts> {
  // For adding a new contact
  final TextEditingController nameController = TextEditingController();
  final TextEditingController organizationController = TextEditingController();
  final TextEditingController positionController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  String searchQuery = '';
  String get userId => UserSession().userId ?? '';
  List<Contact> contacts = [];
  List<Contact> starred = [];
  Set<dynamic> selectedIDs = {};
  Map<String, List<Contact>> sections = {};
  bool addingContact = false;
  bool searching = false;
  Contact? openedContact;

  // stores data about how individual contacts in the list look like and how they react
  Widget buildContactTiles(List<Contact> contacts, {bool starred = false}) {
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
        // Use string comparison for MongoDB ObjectId equality
        final isSelected = selectedIDs.any(
          (id) => id.toString() == contact.id.toString(),
        );
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
                    // Add the MongoDB ObjectId to selection
                    selectedIDs.add(contact.id);
                  }
                  searching = false;
                });
              },
              onTap: () {
                setState(() {
                  if (isSelected) {
                    // Remove from selection using ObjectId
                    selectedIDs.removeWhere(
                      (id) => id.toString() == contact.id.toString(),
                    );
                  } else if (selectedIDs.isNotEmpty) {
                    // Add to selection
                    selectedIDs.add(contact.id);
                  } else {
                    // Open contact details
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
    if (userId.isEmpty) {
      print("No user ID available. Cannot load contacts.");
      contacts = [];
      return;
    }

    // Fetch contacts using the adapter which tries Node.js API first, then falls back to MongoDB
    try {
      List<Map<String, dynamic>> fetchedContacts =
          await ContactsAdapter.getContacts();

      // Convert documents to Contact objects
      contacts = fetchedContacts.map((doc) => Contact.fromMongo(doc)).toList();

      print("Successfully loaded ${contacts.length} contacts for user $userId");
    } catch (e) {
      print("Error loading contacts: $e");
      contacts = [];

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load contacts: $e'),
            duration: Duration(seconds: 2),
          ),
        );
      }
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
    if (userId.isEmpty) {
      print("No user ID available. Cannot star contacts.");
      return;
    }

    if (selectedIDs.isEmpty) return;

    // Get contacts to be starred for optimistic update
    final contactsToStar =
        contacts
            .where(
              (c) => selectedIDs.any((id) => id.toString() == c.id.toString()),
            )
            .toList();

    // Use optimistic updates for bulk starring
    await OptimisticUpdates.perform(
      updateLocalState: () {
        setState(() {
          for (var contact in contactsToStar) {
            contact.starred = 1;
          }
        });
      },
      databaseOperation: () async {
        bool allSuccess = true;
        for (var contact in contactsToStar) {
          bool success = await ContactsAdapter.toggleStarContact(
            contact.id,
            true,
          );
          if (!success) allSuccess = false;
        }
        return allSuccess;
      },
      revertLocalState: () {
        setState(() {
          for (var contact in contactsToStar) {
            contact.starred = 0;
          }
        });
      },
      showSuccessMessage: 'Contacts starred successfully!',
      showErrorMessage: 'Failed to star some contacts',
      context: context,
      onSuccess: () async {
        await begin(); // Reload to ensure consistency
      },
    );
  }

  void deStarSelected() async {
    if (userId.isEmpty) {
      print("No user ID available. Cannot unstar contacts.");
      return;
    }

    if (selectedIDs.isEmpty) return;

    // Get contacts to be unstarred for optimistic update
    final contactsToUnstar =
        contacts
            .where(
              (c) => selectedIDs.any((id) => id.toString() == c.id.toString()),
            )
            .toList();

    // Use optimistic updates for bulk unstarring
    await OptimisticUpdates.perform(
      updateLocalState: () {
        setState(() {
          for (var contact in contactsToUnstar) {
            contact.starred = 0;
          }
        });
      },
      databaseOperation: () async {
        bool allSuccess = true;
        for (var contact in contactsToUnstar) {
          bool success = await ContactsAdapter.toggleStarContact(
            contact.id,
            false,
          );
          if (!success) allSuccess = false;
        }
        return allSuccess;
      },
      revertLocalState: () {
        setState(() {
          for (var contact in contactsToUnstar) {
            contact.starred = 1;
          }
        });
      },
      showSuccessMessage: 'Contacts unstarred successfully!',
      showErrorMessage: 'Failed to unstar some contacts',
      context: context,
      onSuccess: () async {
        await begin(); // Reload to ensure consistency
      },
    );
  }

  void deleteSelected() async {
    if (userId.isEmpty) {
      print("No user ID available. Cannot delete contacts.");
      return;
    }

    if (selectedIDs.isEmpty) return;

    // Get contacts to be deleted for optimistic update
    final contactsToDelete =
        contacts
            .where(
              (c) => selectedIDs.any((id) => id.toString() == c.id.toString()),
            )
            .toList();

    // Use optimistic updates for bulk deletion
    await OptimisticUpdates.perform(
      updateLocalState: () {
        setState(() {
          // Remove contacts from the list immediately
          contacts.removeWhere(
            (c) => selectedIDs.any((id) => id.toString() == c.id.toString()),
          );
          selectedIDs.clear();
        });
      },
      databaseOperation: () async {
        bool allSuccess = true;
        for (var contact in contactsToDelete) {
          bool success = await ContactsAdapter.deleteContact(contact.id);
          if (!success) allSuccess = false;
        }
        return allSuccess;
      },
      revertLocalState: () {
        setState(() {
          // Re-add the contacts if deletion failed
          contacts.addAll(contactsToDelete);
          selectedIDs.clear();
        });
      },
      showSuccessMessage: 'Contacts deleted successfully!',
      showErrorMessage: 'Failed to delete some contacts',
      context: context,
      onSuccess: () async {
        await begin(); // Reload to ensure consistency
      },
    );
  }

  void selectAll() {
    // Add all contact MongoDB ObjectIds to the selection
    selectedIDs.addAll(contacts.map((contact) => contact.id));
  }

  bool allAreSelected() {
    // When using MongoDB ObjectIds, we need to do string comparison
    return contacts.every((contact) {
      return selectedIDs.any((id) => id.toString() == contact.id.toString());
    });
  }

  bool allSeletedAreStarred() {
    return selectedIDs.every((id) {
      // With MongoDB ObjectIds, we need to use equality differently
      // Since ObjectId equality uses toString() comparison, we'll find matching contacts
      try {
        var contact = contacts.firstWhere(
          (c) => c.id.toString() == id.toString(),
        );
        return contact.starred == 1;
      } catch (e) {
        // If contact not found, consider it not starred
        print(
          "Warning: Contact with ID ${id.toString()} not found in allSeletedAreStarred()",
        );
        return false;
      }
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
    if (widget.contactToOpen != null) {
      openedContact = widget.contactToOpen;
    }
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
                      if (!searching) ...[
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
                      ] else ...[
                        Container(
                          margin: const EdgeInsets.only(
                            left: 36,
                            top: 5,
                            bottom: 5,
                            right: 5,
                          ),
                          width: MediaQuery.of(context).size.width * 0.6,
                          decoration: standardTile(10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: searchController,
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                  ),
                                  cursorColor:
                                      Theme.of(context).colorScheme.tertiary,
                                  decoration: InputDecoration(
                                    hintText: 'Search',
                                    labelText: 'Search contacts',
                                    labelStyle: TextStyle(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSecondary,
                                    ),
                                    hintStyle: TextStyle(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSecondary,
                                    ),
                                    border: const UnderlineInputBorder(),
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      searchQuery = value.trim().toLowerCase();
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (selectedIDs.isEmpty) ...[
                        Container(
                          margin: EdgeInsets.only(right: 20),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  !searching
                                      ? Icons.search
                                      : Icons.cancel_outlined,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                  size: !searching ? 30 : 25,
                                ),
                                onPressed: () {
                                  setState(() {
                                    searching = !searching;
                                    searchController.clear();
                                  });
                                },
                              ),
                              if (!searching) ...[
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
                                    if (userId.isEmpty) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Please log in to import/export contacts',
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    await requestStoragePermission(); // ask for permission first

                                    final jsonPath =
                                        '/storage/emulated/0/Download/contacts_export.json';
                                    final jsonFile = File(jsonPath);
                                    if (value == 'export') {
                                      try {
                                        // Get JSON export from adapter (via Node.js API or MongoDB)
                                        final jsonData =
                                            await ContactsAdapter.exportContactsAsJson();
                                        if (jsonData == null) {
                                          throw Exception(
                                            'No contacts to export',
                                          );
                                        }

                                        // Write to JSON file
                                        await jsonFile.writeAsString(jsonData);

                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Exported successfully to Download/contacts_export.json!',
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Export failed: $e',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    } else if (value == 'import') {
                                      try {
                                        if (await jsonFile.exists()) {
                                          // Read JSON data
                                          final jsonString =
                                              await jsonFile.readAsString();
                                          final List<dynamic> contactsData =
                                              jsonDecode(jsonString);

                                          // Convert to proper format
                                          final contactsList =
                                              contactsData
                                                  .map(
                                                    (item) => Map<
                                                      String,
                                                      dynamic
                                                    >.from(item),
                                                  )
                                                  .toList(); // Import using our adapter (Node.js API first, then MongoDB fallback)
                                          await ContactsAdapter.importContacts(
                                            contactsList,
                                          );

                                          await begin(); // refresh contacts

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
                                                  'contacts_export.json not found in Downloads',
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Import failed: $e',
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
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: const [
                                              Text('Import'),
                                              Icon(
                                                Icons.file_download_outlined,
                                              ),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'export',
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: const [
                                              Text('Export'),
                                              Icon(Icons.file_upload_outlined),
                                            ],
                                          ),
                                        ),
                                      ],
                                ),
                              ],
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
                        if (userId.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Please log in to add contacts'),
                            ),
                          );
                          return;
                        }

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
                        } // Create contact data
                        final contactData = {
                          'name': nameController.text.trim(),
                          'organization': organizationController.text.trim(),
                          'phoneNumber': phoneController.text.trim(),
                          'position': positionController.text.trim(),
                          'starred': 0,
                          'type': 'contact', // Add type field
                          'created_at':
                              DateTime.now(), // Store as Date type in MongoDB
                        }; // Create temporary contact for optimistic update
                        final tempContact = Contact(
                          id:
                              DateTime.now().millisecondsSinceEpoch
                                  .toString(), // Temporary ID
                          name: contactData['name'] as String,
                          organization: contactData['organization'] as String,
                          phoneNumber: contactData['phoneNumber'] as String,
                          position: contactData['position'] as String,
                          starred: 0,
                        );

                        clearForm(); // Clear the form first for better UX

                        // Use optimistic updates for contact creation
                        await OptimisticUpdates.performListOperation<Contact>(
                          list: contacts,
                          operation: 'add',
                          item: tempContact,
                          databaseOperation: () async {
                            return await ContactsAdapter.addContact(
                              contactData,
                            );
                          },
                          showSuccessMessage: 'Contact added successfully!',
                          showErrorMessage: 'Failed to add contact',
                          context: context,
                          onSuccess: () async {
                            // Reload contacts to get the real contact with database ID
                            await begin();
                          },
                          onError: (error) {
                            setState(
                              () {},
                            ); // Trigger rebuild to remove optimistic contact
                          },
                        );
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
                    // Show different layouts based on search state
                    if (searchQuery.isEmpty) ...[
                      // Normal view with sections when not searching
                      ...(() {
                        if (starred.isNotEmpty) {
                          return [
                            Container(
                              margin: const EdgeInsets.only(left: 40),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
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
                            buildContactTiles(starred, starred: true),
                          ];
                        }
                        return <Widget>[];
                      })(),
                      // Show alphabetical sections
                      for (var entry in sections.entries)
                        ...(() {
                          if (entry.value.isNotEmpty) {
                            return [
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
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onPrimary,
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
                              buildContactTiles(entry.value),
                            ];
                          } else {
                            return <Widget>[];
                          }
                        })(),
                    ] else ...[
                      // Search view - flat list without sections
                      ...(() {
                        List<Contact> allFilteredContacts = [];

                        // Filter starred contacts by search query
                        final filteredStarredContacts =
                            starred
                                .where(
                                  (contact) =>
                                      contact.name.toLowerCase().contains(
                                        searchQuery.toLowerCase(),
                                      ) ||
                                      contact.phoneNumber
                                          .toLowerCase()
                                          .contains(searchQuery.toLowerCase()),
                                )
                                .toList();

                        // Filter all other contacts by search query
                        final filteredRegularContacts =
                            contacts
                                .where(
                                  (contact) =>
                                      contact.starred == 0 &&
                                      (contact.name.toLowerCase().contains(
                                            searchQuery.toLowerCase(),
                                          ) ||
                                          contact.phoneNumber
                                              .toLowerCase()
                                              .contains(
                                                searchQuery.toLowerCase(),
                                              )),
                                )
                                .toList();

                        // Combine all filtered contacts
                        allFilteredContacts.addAll(filteredStarredContacts);
                        allFilteredContacts.addAll(filteredRegularContacts);

                        // Sort all contacts: starts with query first, then contains query
                        allFilteredContacts.sort((a, b) {
                          final aNameStartsWith = a.name
                              .toLowerCase()
                              .startsWith(searchQuery.toLowerCase());
                          final bNameStartsWith = b.name
                              .toLowerCase()
                              .startsWith(searchQuery.toLowerCase());
                          final aPhoneStartsWith = a.phoneNumber
                              .toLowerCase()
                              .startsWith(searchQuery.toLowerCase());
                          final bPhoneStartsWith = b.phoneNumber
                              .toLowerCase()
                              .startsWith(searchQuery.toLowerCase());

                          final aStartsWith =
                              aNameStartsWith || aPhoneStartsWith;
                          final bStartsWith =
                              bNameStartsWith || bPhoneStartsWith;

                          if (aStartsWith && !bStartsWith) return -1;
                          if (!aStartsWith && bStartsWith) return 1;

                          // If both start with query, prioritize name matches over phone matches
                          if (aStartsWith && bStartsWith) {
                            if (aNameStartsWith && !bNameStartsWith) return -1;
                            if (!aNameStartsWith && bNameStartsWith) return 1;
                          }

                          // Finally sort by name
                          return a.name.compareTo(b.name);
                        });

                        if (allFilteredContacts.isNotEmpty) {
                          return [buildContactTiles(allFilteredContacts)];
                        } else {
                          return [
                            Container(
                              margin: EdgeInsets.only(top: 50),
                              child: Center(
                                child: Text(
                                  'No contacts found',
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.tertiary,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ];
                        }
                      })(),
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
  late Contact localContact;

  // Get current user's ID for MongoDB operations
  String get userId => UserSession().userId ?? '';
  @override
  void initState() {
    super.initState();
    // Create a local copy of the contact
    localContact = widget.contact.copyWith();

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
                              if (userId.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please log in to update contacts',
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }

                              // Store original contact for potential rollback
                              final originalContact = localContact.copyWith();

                              // Use optimistic updates for contact editing
                              await OptimisticUpdates.perform(
                                updateLocalState: () {
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
                                },
                                databaseOperation: () async {
                                  return await ContactsAdapter.updateContact({
                                    '_id': localContact.id,
                                    'name': nameController.text.trim(),
                                    'organization':
                                        organizationController.text.trim(),
                                    'phoneNumber': phoneController.text.trim(),
                                    'position': positionController.text.trim(),
                                    'starred': starred ? 1 : 0,
                                    'type': 'contact',
                                  });
                                },
                                revertLocalState: () {
                                  setState(() {
                                    localContact = originalContact;
                                    editingContact = true;
                                  });
                                },
                                showSuccessMessage:
                                    'Contact updated successfully!',
                                showErrorMessage: 'Failed to update contact',
                                context: context,
                              );
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
                      if (userId.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Please log in to update contacts'),
                          ),
                        );
                        return;
                      } // Use optimistic updates for star toggle
                      await OptimisticUpdates.perform(
                        updateLocalState: () {
                          setState(() {
                            starred = !starred;
                            localContact = localContact.copyWith(
                              starred: starred ? 1 : 0,
                            );
                          });
                        },
                        databaseOperation: () async {
                          return await ContactsAdapter.toggleStarContact(
                            localContact.id,
                            starred,
                          );
                        },
                        revertLocalState: () {
                          setState(() {
                            starred = !starred;
                            localContact = localContact.copyWith(
                              starred: starred ? 1 : 0,
                            );
                          });
                        },
                        showSuccessMessage:
                            starred ? 'Contact starred!' : 'Contact unstarred!',
                        showErrorMessage: 'Failed to update star status',
                        context: context,
                      );
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
