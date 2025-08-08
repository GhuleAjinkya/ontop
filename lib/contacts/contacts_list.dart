// dependencies
import 'dart:io';
import 'dart:ui'; // For ImageFilter
import 'dart:convert'; // For JSON encoding/decoding
import '../shared/user_session.dart';
import 'contacts_adapter.dart'; // Add our new adapter
import '../shared/optimistic_updates.dart'; // Add optimistic updates
import 'contact_import_screen.dart'; // Add contact import screen
import 'contact_model.dart';
import 'contact_details.dart';
import '../shared/dialog_helper.dart'; // Add dialog helper
import 'package:flutter/material.dart';
import '../main.dart';
import 'package:permission_handler/permission_handler.dart';

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
  final TextEditingController emailController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  String searchQuery = '';
  String get userId => UserSession().userId ?? '';
  List<Contact> contacts = [];
  List<Contact> starred = [];
  Set<dynamic> selectedIDs = {};
  Map<String, List<Contact>> sections = {};
  bool addingContact = false;
  bool searching = false;
  bool fetchingContacts = false;
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
      setState(() {
        fetchingContacts = true;
      });
      List<Map<String, dynamic>> fetchedContacts =
          await ContactsAdapter.getContacts();

      // Convert documents to Contact objects
      contacts = fetchedContacts.map((doc) => Contact.fromMongo(doc)).toList();

      print("Successfully loaded ${contacts.length} contacts for user $userId");
      print(contacts);
      setState(() {
        fetchingContacts = false;
      });
    } catch (e) {
      print("Error loading contacts: $e");
      contacts = [];

      if (mounted) {
        setState(() {
          fetchingContacts = false;
        });
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
    for (var contact in contacts.where((c) => c.starred == false)) {
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

    starred = contacts.where((c) => c.starred == true).toList();
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
      emailController.clear(); // Clear email field
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
            contact.starred = true;
            sections.forEach((key, list) {
              list.removeWhere((c) => c.id.toString() == contact.id.toString());
            });
            if (!starred.any((c) => c.id.toString() == contact.id.toString())) {
              starred.add(contact);
            }
          }
          starred.sort((a, b) => a.name.compareTo(b.name));
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
            contact.starred = false;
            starred.remove(contact);
            if (contact.name.isNotEmpty) {
              String firstLetter = contact.name[0].toUpperCase();
              if (sections.containsKey(firstLetter)) {
                sections[firstLetter]!.add(contact);
              }
            }
          }
          sections.forEach((key, list) {
            if (list.isNotEmpty) {
              list.sort((a, b) => a.name.compareTo(b.name));
            }
          });
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
 // TODO combine star and unstar functions into one
 // TODO update edit and star icons to be in line with the pfp
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
            // Update starred status
            contact.starred = false;

            // Remove from starred list
            starred.remove(contact);

            // Add to appropriate section
            if (contact.name.isNotEmpty) {
              String firstLetter = contact.name[0].toUpperCase();
              if (sections.containsKey(firstLetter)) {
                sections[firstLetter]!.add(contact);
                // Sort the section
                sections[firstLetter]!.sort((a, b) => a.name.compareTo(b.name));
              }
            }
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
            // Revert starred status back to 1
            contact.starred = true;

            // Remove from sections if present
            sections.forEach((key, list) {
              list.removeWhere((c) => c.id.toString() == contact.id.toString());
            });

            // Add back to starred list if not present
            if (!starred.any((c) => c.id.toString() == contact.id.toString())) {
              starred.add(contact);
            }
          }

          // Sort starred list
          starred.sort((a, b) => a.name.compareTo(b.name));
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
    print("🔴 DEBUG: Starting deleteSelected()");
    print("🔴 DEBUG: userId = '$userId'");
    print("🔴 DEBUG: selectedIDs = $selectedIDs");
    print("🔴 DEBUG: selectedIDs.length = ${selectedIDs.length}");

    if (userId.isEmpty) {
      print("🔴 DEBUG: No user ID available. Cannot delete contacts.");
      return;
    }

    if (selectedIDs.isEmpty) {
      print("🔴 DEBUG: No contacts selected for deletion");
      return;
    }

    // Get contacts to be deleted for optimistic update
    final contactsToDelete =
        contacts
            .where(
              (c) => selectedIDs.any((id) => id.toString() == c.id.toString()),
            )
            .toList();

    print("🔴 DEBUG: contactsToDelete.length = ${contactsToDelete.length}");
    for (var contact in contactsToDelete) {
      print(
        "🔴 DEBUG: Contact to delete: ${contact.name} (ID: ${contact.id}, Type: ${contact.id.runtimeType})",
      );
    }

    // Use optimistic updates for bulk deletion
    print("🔴 DEBUG: Starting OptimisticUpdates.perform()");
    await OptimisticUpdates.perform(
      updateLocalState: () {
        print(
          "🔴 DEBUG: Executing updateLocalState - removing contacts from UI",
        );
        setState(() {
          // Remove from main contacts list
          contacts.removeWhere(
            (c) => selectedIDs.any((id) => id.toString() == c.id.toString()),
          );

          // Remove from sections
          sections.forEach((key, list) {
            list.removeWhere(
              (c) => selectedIDs.any((id) => id.toString() == c.id.toString()),
            );
          });

          // Remove from starred if present
          starred.removeWhere(
            (c) => selectedIDs.any((id) => id.toString() == c.id.toString()),
          );

          selectedIDs.clear();
        });
      },
      databaseOperation: () async {
        print("🔴 DEBUG: Starting databaseOperation");
        bool allSuccess = true;
        for (var contact in contactsToDelete) {
          print(
            "🔴 DEBUG: Attempting to delete contact: ${contact.name} (ID: ${contact.id})",
          );
          bool success = await ContactsAdapter.deleteContact(contact.id);
          print("🔴 DEBUG: Delete result for ${contact.name}: $success");
          if (!success) allSuccess = false;
        }
        print("🔴 DEBUG: Overall databaseOperation result: $allSuccess");
        return allSuccess;
      },
      revertLocalState: () {
        print("🔴 DEBUG: Executing revertLocalState - restoring contacts");
        setState(() {
          // Add back to main contacts list
          contacts.addAll(contactsToDelete);

          // Add back to sections
          for (var contact in contactsToDelete) {
            if (contact.starred == false && contact.name.isNotEmpty) {
              String firstLetter = contact.name[0].toUpperCase();
              if (sections.containsKey(firstLetter)) {
                sections[firstLetter]!.add(contact);
              }
            }
          }

          // Add back to starred if they were starred
          starred.addAll(contactsToDelete.where((c) => c.starred == true));

          // Re-select the contacts
          selectedIDs.addAll(contactsToDelete.map((c) => c.id));
        });
      },
      showSuccessMessage: 'Contacts deleted successfully!',
      showErrorMessage: 'Failed to delete some contacts',
      context: context,
      onSuccess: () async {
        print("🔴 DEBUG: Delete success callback - reloading contacts");
        await begin(); // Reload to ensure consistency
      },
    );
    print("🔴 DEBUG: deleteSelected() completed");
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
        return contact.starred == true;
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

  void _showContactDialog({Contact? contact}) {
    final isEditing = contact != null;
    final titleController = TextEditingController(text: contact?.name ?? '');
    final organizationController = TextEditingController(
      text: contact?.organization ?? '',
    );
    final positionController = TextEditingController(
      text: contact?.position ?? '',
    );
    final phoneController = TextEditingController(
      text: contact?.phoneNumber ?? '',
    );
    final emailController = TextEditingController(text: contact?.email ?? '');

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.onPrimary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            title: Text(
              isEditing ? 'Edit Contact' : 'Add New Contact',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.85,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDialogTextField(
                      controller: titleController,
                      label: 'Name',
                      hint: 'Enter contact name',
                    ),
                    SizedBox(height: 16),
                    _buildDialogTextField(
                      controller: phoneController,
                      label: 'Phone Number',
                      hint: 'Enter phone number',
                      keyboardType: TextInputType.phone,
                    ),
                    SizedBox(height: 16),
                    _buildDialogTextField(
                      controller: positionController,
                      label: 'Position',
                      hint: 'Enter position',
                    ),
                    SizedBox(height: 16),
                    _buildDialogTextField(
                      controller: organizationController,
                      label: 'Organization',
                      hint: 'Enter organization',
                    ),
                    SizedBox(height: 16),
                    _buildDialogTextField(
                      controller: emailController,
                      label: 'Email (Optional)',
                      hint: 'Enter email address',
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.tertiary,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              ElevatedButton(
                onPressed:
                    () => _saveContact(
                      contact: contact,
                      name: titleController.text,
                      phoneNumber: phoneController.text,
                      position: positionController.text,
                      organization: organizationController.text,
                      email: emailController.text,
                    ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: Text(
                  isEditing ? 'Update' : 'Add',
                  style: TextStyle(fontFamily: 'Poppins'),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onPrimary,
        fontFamily: 'Poppins',
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: Theme.of(context).colorScheme.tertiary,
          fontFamily: 'Poppins',
        ),
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.7),
          fontFamily: 'Poppins',
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.tertiary.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.secondary,
            width: 2,
          ),
        ),
      ),
    );
  }

  void _saveContact({
    Contact? contact,
    required String name,
    required String phoneNumber,
    required String position,
    required String organization,
    required String email,
  }) async {
    if (name.trim().isEmpty ||
        phoneNumber.trim().isEmpty ||
        position.trim().isEmpty ||
        organization.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Name, phone, position, and organization are required'),
        ),
      );
      return;
    }

    if (userId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please log in to save contacts')));
      return;
    }
    
    Navigator.pop(context);

    // Create contact data
    final contactData = {
      'name': name.trim(),
      'organization': organization.trim(),
      'phoneNumber': phoneNumber.trim(),
      'position': position.trim(),
      'email': email.trim(),
      'notes': contact?.notes ?? '',
      'starred': contact?.starred ?? false,
      'type': 'contact',
      'created_at': DateTime.now(),
    };

    // Create temporary contact for optimistic update
    final tempContact = Contact(
      id: contact?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: contactData['name'] as String,
      organization: contactData['organization'] as String,
      phoneNumber: contactData['phoneNumber'] as String,
      position: contactData['position'] as String,
      email: contactData['email'] as String,
      notes: contactData['notes'] as String,
      starred: contactData['starred'] as bool,
    );

    bool success;
    if (contact != null) {
      // Update existing contact
      success = await ContactsAdapter.updateContact({
        '_id': contact.id,
        ...contactData,
      });
    } else {
      // Create new contact
      await OptimisticUpdates.performListOperation<Contact>(
        list: contacts,
        operation: 'add',
        item: tempContact,
        databaseOperation: () async {
          return await ContactsAdapter.addContact(contactData);
        },
        showSuccessMessage: 'Contact added successfully!',
        showErrorMessage: 'Failed to add contact',
        context: context,
        onSuccess: () async {
          await begin();
        },
        onError: (error) {
          setState(() {});
        },
      );
      return;
    }

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Contact updated successfully')));
      await begin();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save contact')));
    }
  }

  Widget buildSectionHeader( {bool starred = false, String title = "Title Not Provided"}) {
    return Container(
      margin: const EdgeInsets.only(left: 40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          starred ? 
            Icon(
              Icons.star_rounded,
              color: Theme.of(context).colorScheme.onPrimary,
              size: 20,
            )
            : Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onPrimary,
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
    );
  }

  Widget _buildHeader() {
    bool allStarred = allSeletedAreStarred();
    bool allSelected = allAreSelected();

    return Container(
      color: Theme.of(context).colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (!searching) ...[
              Container(
                margin: EdgeInsets.only(left: 40),
                child: Row(
                  children: [
                    Text(
                      "Contacts",
                      style: TextStyle(
                        fontSize: 28,
                        color:
                            Theme.of(
                              context,
                            ).colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(
                    left: 40,
                    top: 8,
                    bottom: 8,
                    right: 20,
                  ),
                  height: 45,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onPrimary
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimary
                          .withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 12,
                        ),
                        child: Icon(
                          Icons.search,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimary
                              .withValues(alpha: 0.6),
                          size: 20,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          style: TextStyle(
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.onPrimary,
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                          ),
                          cursorColor:
                              Theme.of(
                                context,
                              ).colorScheme.tertiary,
                          decoration: InputDecoration(
                            hintText: 'Search contacts...',
                            hintStyle: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimary
                                  .withValues(alpha: 0.5),
                              fontFamily: 'Poppins',
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              searchQuery =
                                  value.trim().toLowerCase();
                            });
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              searchController.clear();
                              searchQuery = '';
                              searching = false;
                            });
                          },
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimary
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(
                                10,
                              ),
                            ),
                            child: Icon(
                              Icons.close,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimary
                                  .withValues(alpha: 0.7),
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (selectedIDs.isEmpty) ...[
              Container(
                margin: EdgeInsets.only(right: 20),
                child: Row(
                  children: [
                    if (!searching) ...[
                      IconButton(
                        icon: Icon(
                          Icons.search,
                          color:
                              Theme.of(
                                context,
                              ).colorScheme.onPrimary,
                          size: 30,
                        ),
                        onPressed: () {
                          setState(() {
                            searching = true;
                          });
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.add,
                          color:
                              Theme.of(
                                context,
                              ).colorScheme.onPrimary,
                          size: 26,
                        ),
                        onPressed: () => _showContactDialog(),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          color:
                              Theme.of(
                                context,
                              ).colorScheme.onPrimary,
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

                          if (value == 'import_phone') {
                            // Navigate to phone contact import screen
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (
                                      context,
                                    ) => ContactImportScreen(
                                      onContactsImported: () {
                                        // Reload contacts after import
                                        begin();
                                      },
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
                              await jsonFile.writeAsString(
                                jsonData,
                              );

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
                                value: 'import_phone',
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .spaceBetween,
                                  children: const [
                                    Text('Import from Phone'),
                                    Icon(Icons.phone_android),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'import',
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .spaceBetween,
                                  children: const [
                                    Text('Import from File'),
                                    Icon(
                                      Icons
                                          .file_download_outlined,
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'export',
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .spaceBetween,
                                  children: const [
                                    Text('Export'),
                                    Icon(
                                      Icons.file_upload_outlined,
                                    ),
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
                            Theme.of(
                              context,
                            ).colorScheme.onPrimary,
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
                            Theme.of(
                              context,
                            ).colorScheme.onPrimary,
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
                            Theme.of(
                              context,
                            ).colorScheme.onPrimary,
                        size: 28,
                      ),
                      onPressed: () {
                        DialogHelper.showDeleteConfirmation(
                          context: context,
                          title: 'Delete Contacts?',
                          content:
                              'Selected contacts will be permanently deleted.',
                          onDelete: () {
                            deleteSelected();
                          },
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
    );
  }


  @override
  void initState() {
    super.initState();
    print("Called Contacts initState");
    begin();
    if (widget.contactToOpen != null) {
      openedContact = widget.contactToOpen;
    }
  }

  @override
  Widget build(BuildContext context) {

    if (openedContact != null) {
      return ContactDetails(
        contact: openedContact!,
        onBack: () {
          setState(() {
            openedContact = null;
          });
        },
        onUpdate: (updatedContact) {
          setState(() {
            // Update in main contacts list
            final idx = contacts.indexWhere(
              (c) => c.id.toString() == updatedContact.id.toString(),
            );
            if (idx != -1) {
              contacts[idx] = updatedContact;
            }

            // Remove from all sections
            for (var list in sections.values) {
              list.removeWhere(
                (c) => c.id.toString() == updatedContact.id.toString(),
              );
            }

            // Handle starred/unstarred logic
            final starredIdx = starred.indexWhere(
              (c) => c.id.toString() == updatedContact.id.toString(),
            );
            if (updatedContact.starred) {
              // Add to starred if not present
              if (starredIdx == -1) {
                starred.add(updatedContact);
                starred.sort((a, b) => a.name.compareTo(b.name));
              } else {
                starred[starredIdx] = updatedContact;
              }
              // Do NOT add to sections (starred contacts should not appear in sections)
            } else {
              // Remove from starred if present
              if (starredIdx != -1) {
                starred.removeAt(starredIdx);
              }
              // Add to correct section
              final firstLetter =
                  updatedContact.name.isNotEmpty
                      ? updatedContact.name[0].toUpperCase()
                      : '';
              if (sections.containsKey(firstLetter)) {
                sections[firstLetter]!.add(updatedContact);
                sections[firstLetter]!.sort((a, b) => a.name.compareTo(b.name));
              }
            }

            // Update openedContact if needed
            openedContact = updatedContact;
          });
        },
      );
    }
    return Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: Stack(
          children: [
            // Purple blob 1 - Top left area 
            Positioned(
              top: 80,
              left: 10, // Moved further right towards center
              child: Container(
                width: 140,
                height: 200,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary.withValues(
                    alpha: 0.6,
                  ), // Lighter than original
                  borderRadius: BorderRadius.circular(100),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 60, sigmaY: 45),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            // Purple blob 2 - Middle right area 
            Positioned(
              top: MediaQuery.of(context).size.height * 0.4,
              right: -50, // Moved further left towards center
              child: Container(
                width: 170,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.secondary.withValues(
                    alpha: 0.5,
                  ), // Even lighter
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            // Purple blob 3 - Bottom center area 
            Positioned(
              bottom: -60,
              left:
                  MediaQuery.of(context).size.width *
                  0.3, // Centered horizontally
              child: Container(
                width: 150,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.secondary.withValues(
                    alpha: 0.4,
                  ), // Even more subtle
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            // Purple blob 4 - Middle center area
            Positioned(
              top: MediaQuery.of(context).size.height * 0.6,
              left: MediaQuery.of(context).size.width * 0.15,
              child: Container(
                width: 100,
                height: 130,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary.withValues(
                    alpha: 0.3,
                  ), // Very subtle and dreamy
                  borderRadius: BorderRadius.circular(60),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 50, sigmaY: 65),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            // Main content
            Container(
              color: Colors.transparent,
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        if (starred.isEmpty && sections.entries.every((c) => c.value.isEmpty)) ...[
                          Container(
                            // Fetching Contacts widget
                            margin: EdgeInsets.only(top: 150),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                spacing: 10,
                                children: [
                                  fetchingContacts
                                      ? CircularProgressIndicator(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.tertiary,
                                      )
                                      : Icon(
                                        Icons.person,
                                        size: 80,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.tertiary,
                                      ),
                                  Text(
                                    fetchingContacts
                                        ? 'Fetching Contacts...'
                                        : 'No added contacts.',
                                    style: TextStyle(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
                          if (searchQuery.isEmpty) ...[
                            ...(() {
                              if (starred.isNotEmpty) {
                                return [
                                  buildSectionHeader(starred: true),
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
                                    // regular sections return widget
                                    const Divider(
                                      height: 1,
                                      color: Colors.transparent,
                                    ),
                                    buildSectionHeader(title: entry.key),
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
                                                .contains(
                                                  searchQuery.toLowerCase(),
                                                ),
                                      )
                                      .toList();

                              // Filter all other contacts by search query
                              final filteredRegularContacts =
                                  contacts
                                      .where(
                                        (contact) =>
                                            contact.starred == false &&
                                            (contact.name
                                                    .toLowerCase()
                                                    .contains(
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
                              allFilteredContacts.addAll(
                                filteredStarredContacts,
                              );
                              allFilteredContacts.addAll(
                                filteredRegularContacts,
                              );

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
                                  if (aNameStartsWith && !bNameStartsWith) {
                                    return -1;
                                  }
                                  if (!aNameStartsWith && bNameStartsWith) {
                                    return 1;
                                  }
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
                                              Theme.of(
                                                context,
                                              ).colorScheme.tertiary,
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
