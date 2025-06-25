// dependencies
import 'dart:io';
import 'dart:ui'; // For ImageFilter
import 'dart:convert'; // For JSON encoding/decoding
import '../shared/user_session.dart';
import 'contacts_adapter.dart'; // Add our new adapter
import '../shared/optimistic_updates.dart'; // Add optimistic updates
import '../projects/projects_adapter.dart'; // Add projects adapter
import 'contact_import_screen.dart'; // Add contact import screen
import 'contact_model.dart';
import '../projects/project_model.dart'; // Add project model
import '../shared/dialog_helper.dart'; // Add dialog helper
// Add app title widget
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

// Contact Object for MongoDB data


ScaffoldFeatureController<SnackBar, SnackBarClosedReason> updatingSnackBar(
  BuildContext context,
) {
  return ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Please wait. Updating Contacts...'),
      duration: Duration(seconds: 1),
      showCloseIcon: true,
    ),
  );
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
  final TextEditingController emailController =
      TextEditingController(); // Add email controller
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
    bool allStarred = allSeletedAreStarred();
    bool allSelected = allAreSelected();

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
            // Purple blob 1 - Top left area (shifted more towards center)
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
            // Purple blob 2 - Middle right area (shifted more towards center)
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
            // Purple blob 3 - Bottom center area (new magical blob!)
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
            // Purple blob 4 - Middle center area, floating dreamily! ✨
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
              color: Colors.transparent, // Changed from primary to transparent
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
                  ),
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        if (starred.isEmpty &&
                            sections.entries.every((c) => c.value.isEmpty)) ...[
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
                                  // Starred return widget
                                  Container(
                                    margin: const EdgeInsets.only(left: 40),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.star_rounded,
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onPrimary,
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
                                    // regular sections return widget
                                    const Divider(
                                      height: 1,
                                      color: Colors.transparent,
                                    ),
                                    Container(
                                      margin: const EdgeInsets.only(left: 40),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
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
                ], // Close the Stack children
              ),
            ),
          ],
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
    required this.onUpdate,
  });
  final Contact contact;
  final VoidCallback onBack;
  final ValueChanged<Contact> onUpdate;

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

  void openEmail(String email, VoidCallback onError) async {
    try {
      // First try standard mailto
      final Uri mailtoUri = Uri.parse('mailto:$email');
      print('Trying to launch email with URI: $mailtoUri');

      if (await canLaunchUrl(mailtoUri)) {
        await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
        print('Email app launched successfully with mailto');
        return;
      }

      // Try with query parameters for better compatibility
      final Uri mailtoQueryUri = Uri(scheme: 'mailto', path: email);
      print('Trying to launch email with path URI: $mailtoQueryUri');

      if (await canLaunchUrl(mailtoQueryUri)) {
        await launchUrl(mailtoQueryUri, mode: LaunchMode.externalApplication);
        print('Email app launched successfully with path');
        return;
      }

      // Try different launch modes for better emulator compatibility
      try {
        await launchUrl(mailtoUri, mode: LaunchMode.platformDefault);
        print('Email launched with platform default mode');
        return;
      } catch (platformError) {
        print('Platform default launch failed: $platformError');
      }

      // Try Gmail web interface as fallback
      final Uri gmailWebUri = Uri.parse(
        'https://mail.google.com/mail/?view=cm&to=$email',
      );
      print('Trying to launch Gmail web interface: $gmailWebUri');

      if (await canLaunchUrl(gmailWebUri)) {
        await launchUrl(gmailWebUri, mode: LaunchMode.externalApplication);
        print('Gmail web interface launched successfully');
        return;
      }

      print(
        'All email launch methods failed - likely no email apps or browser installed (common on emulators)',
      );
      onError();
    } catch (e) {
      print('Error launching email: $e');
      onError();
    }
  }

  Widget divLine(BuildContext context) {
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        width: MediaQuery.of(context).size.width * 0.8,
        height: 3,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 0.75,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
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
  bool editingNotes = false; // Add notes editing state
  final TextEditingController nameController = TextEditingController();
  final TextEditingController organizationController = TextEditingController();
  final TextEditingController positionController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController =
      TextEditingController(); // Add email controller
  final TextEditingController notesController =
      TextEditingController(); // Add notes controller
  late Contact localContact;

  // Project-related variables
  List<Project> ongoingProjects = [];
  List<Project> completedProjects = [];
  bool loadingProjects = false;
  // Get current user's ID for MongoDB operations
  String get userId => UserSession().userId ?? '';

  // Load projects where this contact is a collaborator
  Future<void> loadContactProjects() async {
    if (userId.isEmpty) {
      print("No user ID available. Cannot load projects.");
      return;
    }

    setState(() {
      loadingProjects = true;
    });

    try {
      // Fetch all projects using ProjectsAdapter
      List<Map<String, dynamic>> fetchedProjects =
          await ProjectsAdapter.getProjects();

      // Convert to Project objects
      List<Project> allProjects =
          fetchedProjects.map((doc) => Project.fromMongo(doc)).toList();

      // Filter projects where this contact's phone number is in collaborators
      List<Project> contactProjects =
          allProjects.where((project) {
            return project.collaborators.contains(localContact.phoneNumber);
          }).toList();

      // Separate ongoing and completed projects
      ongoingProjects =
          contactProjects.where((p) => p.isCompleted != true).toList();
      completedProjects =
          contactProjects.where((p) => p.isCompleted == true).toList();

      // Sort ongoing projects by creation date (most recent first)
      ongoingProjects.sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });

      // Sort completed projects by completion date (most recent first)
      completedProjects.sort((a, b) {
        if (a.completedAt == null && b.completedAt == null) {
          // Fall back to creation date if no completion date
          if (a.createdAt == null && b.createdAt == null) return 0;
          if (a.createdAt == null) return 1;
          if (b.createdAt == null) return -1;
          return b.createdAt!.compareTo(a.createdAt!);
        }
        if (a.completedAt == null) return 1;
        if (b.completedAt == null) return -1;
        return b.completedAt!.compareTo(a.completedAt!);
      });

      print(
        "Loaded ${ongoingProjects.length} ongoing and ${completedProjects.length} completed projects for contact ${localContact.name}",
      );
    } catch (e) {
      print("Error loading projects for contact: $e");
      ongoingProjects = [];
      completedProjects = [];
    } finally {
      if (mounted) {
        setState(() {
          loadingProjects = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Create a local copy of the contact
    localContact = widget.contact.copyWith();
    nameController.text = localContact.name;
    organizationController.text = localContact.organization;
    positionController.text = localContact.position;
    phoneController.text = localContact.phoneNumber;
    emailController.text = localContact.email; // Initialize email field
    notesController.text = localContact.notes; // Initialize notes field

    starred = localContact.starred == true;

    // Load projects for this contact
    loadContactProjects();
  }

  @override
  void dispose() {
    nameController.dispose();
    organizationController.dispose();
    positionController.dispose();
    phoneController.dispose();
    emailController.dispose(); // Dispose email controller
    notesController.dispose(); // Dispose notes controller
    super.dispose();
  } // Navigate to project details

  void navigateToProject(Project project) {
    // Navigate to the Projects tab with the specific project to open
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder:
            (context) => Tabs(
              currentIndex: 2, // Index for Projects tab
              tabs: const ['Tasks', 'Contacts', 'Projects', 'Events'],
              initialProject: project, // Pass the project to open
            ),
      ),
    );
  }

  // Show edit contact dialog
  void _showEditContactDialog() {
    final nameController = TextEditingController(text: localContact.name);
    final organizationController = TextEditingController(
      text: localContact.organization,
    );
    final positionController = TextEditingController(
      text: localContact.position,
    );
    final phoneController = TextEditingController(
      text: localContact.phoneNumber,
    );
    final emailController = TextEditingController(text: localContact.email);

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
              'Edit Contact',
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
                      controller: nameController,
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
                    () => _saveEditedContact(
                      name: nameController.text,
                      phoneNumber: phoneController.text,
                      position: positionController.text,
                      organization: organizationController.text,
                      email: emailController.text,
                    ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: Text('Update', style: TextStyle(fontFamily: 'Poppins')),
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

  void _saveEditedContact({
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please log in to update contacts')),
      );
      return;
    }

    Navigator.pop(context);

    // Store original contact for potential rollback
    final originalContact = localContact.copyWith();

    // Use optimistic updates for contact editing
    await OptimisticUpdates.perform(
      updateLocalState: () {
        setState(() {
          localContact = localContact.copyWith(
            name: name.trim(),
            organization: organization.trim(),
            phoneNumber: phoneNumber.trim(),
            position: position.trim(),
            email: email.trim(),
          );
        });
      },
      databaseOperation: () async {
        return await ContactsAdapter.updateContact({
          '_id': localContact.id,
          'name': name.trim(),
          'organization': organization.trim(),
          'phoneNumber': phoneNumber.trim(),
          'position': position.trim(),
          'email': email.trim(),
          'notes': localContact.notes,
          'starred': localContact.starred,
          'type': 'contact',
        });
      },
      revertLocalState: () {
        setState(() {
          localContact = originalContact;
        });
      },
      showSuccessMessage: 'Contact updated successfully!',
      showErrorMessage: 'Failed to update contact',
      context: context,
      onSuccess: () {
        widget.onUpdate(localContact);
      },
    );
  }

  // Build project list widget
  Widget buildProjectList(List<Project> projects, String sectionTitle) {
    if (projects.isEmpty) {
      return Container();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            sectionTitle,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color:
                  Theme.of(context)
                      .colorScheme
                      .tertiary, // Use tertiary color to differentiate from main title
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...projects.map(
          (project) => Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: InkWell(
              onTap: () => navigateToProject(project),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      project.isCompleted == true
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      color:
                          project.isCompleted == true
                              ? Theme.of(context).colorScheme.tertiary
                              : Theme.of(context).colorScheme.onSecondary,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.title,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (project.description.isNotEmpty) ...[
                            SizedBox(height: 4),
                            Text(
                              project.description,
                              style: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.onSecondary,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Theme.of(context).colorScheme.onSecondary,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          // Purple blob 1 - Top area, centered horizontally behind the box (BIGGER!)
          Positioned(
            top: 20, // Moved up a bit for more spread
            left:
                MediaQuery.of(context).size.width * 0.5 -
                100, // Adjusted for larger size
            child: Container(
              width: 200, // Much bigger!
              height: 240, // Much taller!
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary.withValues(
                  alpha: 0.5,
                ), // Lighter for detail view
                borderRadius: BorderRadius.circular(120),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 80,
                  sigmaY: 60,
                ), // More blur for bigger size
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          // Purple blob 2 - Middle area, centered horizontally behind the box (BIGGER!)
          Positioned(
            top:
                MediaQuery.of(context).size.height *
                0.4, // Slightly lower for more spread
            left:
                MediaQuery.of(context).size.width * 0.5 -
                120, // Adjusted for larger size
            child: Container(
              width: 240, // Much bigger!
              height: 200, // Bigger height!
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.4), // Even lighter
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 100,
                  sigmaY: 100,
                ), // More blur for bigger size
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          // Purple blob 3 - Bottom area, centered horizontally behind the box (BIGGER!)
          Positioned(
            bottom: -60, // Lower for more spread
            left:
                MediaQuery.of(context).size.width * 0.5 -
                110, // Adjusted for larger size
            child: Container(
              width: 220, // Much bigger!
              height: 160, // Bigger height!
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.3), // Most subtle
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 90,
                  sigmaY: 90,
                ), // More blur for bigger size
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
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
                          if (localContact.email.isNotEmpty)
                            Text(
                              localContact.email,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.onSecondary,
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
                              emailController.text =
                                  localContact.email; // Add email field reset
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
                                SizedBox(
                                  child: TextField(
                                    controller: emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    cursorColor:
                                        Theme.of(context).colorScheme.onPrimary,
                                    style: TextStyle(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                      fontSize: 14,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Email (Optional)',
                                      labelText: 'Email',
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
                                      email:
                                          emailController.text
                                              .trim(), // Add email field
                                      notes:
                                          localContact
                                              .notes, // Keep existing notes
                                      starred: starred,
                                    );
                                    editingContact = false;
                                    widget.onUpdate(localContact);
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
                                    'email':
                                        emailController.text
                                            .trim(), // Add email field
                                    'notes':
                                        localContact
                                            .notes, // Keep existing notes
                                    'starred': starred,
                                    'type': 'contact',
                                  });
                                },
                                revertLocalState: () {
                                  setState(() {
                                    localContact = originalContact;
                                    editingContact = true;
                                    widget.onUpdate(localContact);
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
                  Center(
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.8,
                      child: Row(
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
                          IconButton(
                            onPressed: () {
                              if (localContact.email.isEmpty) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "No email address stored for this contact",
                                    ),
                                    backgroundColor:
                                        Theme.of(context).colorScheme.error,
                                  ),
                                );
                                return;
                              }
                              openEmail(localContact.email, () {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "Could not launch email app. This may be due to no email apps being installed (common on emulators). Email functionality works on real devices with email apps installed.",
                                    ),
                                    duration: Duration(seconds: 4),
                                    backgroundColor:
                                        Theme.of(context).colorScheme.error,
                                  ),
                                );
                              });
                            },
                            icon: Icon(
                              Icons.email_outlined,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  divLine(context),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    child: Column(
                      // Notes
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 0,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Notes",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: 16
                              ),
                            ),
                            if (editingNotes) ...[
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      color:
                                          Theme.of(context).colorScheme.onPrimary,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        notesController.text = localContact.notes;
                                        editingNotes = false;
                                      });
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.check,
                                      color:
                                          Theme.of(context).colorScheme.onPrimary,
                                    ),
                                    onPressed: () async {
                                      if (userId.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Please log in to update notes',
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                              
                                      try {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Please wait. Updating notes...',
                                            ),
                                            duration: Duration(seconds: 1),
                                            showCloseIcon: true,
                                          ),
                                        );
                                              
                                        final updatedNotes =
                                            notesController.text.trim();
                                        final updatedContact = localContact
                                            .copyWith(notes: updatedNotes);
                                              
                                        // Update in database using ContactsAdapter
                                        bool success =
                                            await ContactsAdapter.updateContact({
                                              '_id': localContact.id,
                                              'name': localContact.name,
                                              'organization':
                                                  localContact.organization,
                                              'phoneNumber':
                                                  localContact.phoneNumber,
                                              'position': localContact.position,
                                              'email': localContact.email,
                                              'notes': updatedNotes,
                                              'starred': localContact.starred,
                                              'type': 'contact',
                                            });
                                              
                                        if (success) {
                                          setState(() {
                                            localContact = updatedContact;
                                            editingNotes = false;
                                          });
                                          widget.onUpdate(localContact);
                                              
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Notes updated successfully',
                                                ),
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        } else {
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Failed to update notes',
                                                ),
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        }
                                      } catch (e) {
                                        print("Error updating contact notes: $e");
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Error updating notes: $e',
                                              ),
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ] else ...[
                              IconButton(
                                icon: Icon(
                                  Icons.edit,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                                onPressed: () {
                                  setState(() {
                                    editingNotes = true;
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                        TextField(
                          controller: notesController,
                          maxLines: 5,
                          minLines: 1,
                          readOnly: !editingNotes,
                          style: TextStyle(
                            color: editingNotes
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.85),
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: "Add notes about this contact...",
                            hintStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSecondary,
                            ),
                            border:
                                editingNotes
                                    ? OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: BorderSide(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSecondary,
                                        width: 1.2,
                                      ),
                                    )
                                    : InputBorder.none,
                            enabledBorder:
                                editingNotes
                                    ? OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: BorderSide(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSecondary,
                                        width: 1.2,
                                      ),
                                    )
                                    : InputBorder.none,
                            focusedBorder:
                                editingNotes
                                    ? OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: BorderSide(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSecondary,
                                        width: 1.2,
                                      ),
                                    )
                                    : InputBorder.none,
                          ),
                        ),
                      ]
                    ),
                  ),
                  divLine(context),
                  // Dynamic Projects Section
                  if (loadingProjects) ...[
                    ListTile(
                      title: Text(
                        "Projects",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.tertiary,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Loading projects...",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (ongoingProjects.isEmpty &&
                      completedProjects.isEmpty) ...[
                    ListTile(
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
                  ] else ...[
                    // Show projects header
                    Padding(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 16,
                        bottom: 8,
                      ),
                      child: Text(
                        "Projects",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    // Show ongoing projects
                    buildProjectList(ongoingProjects, "Ongoing Projects"),
                    // Show completed projects
                    buildProjectList(completedProjects, "Completed Projects"),
                  ],
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
                      _showEditContactDialog();
                    },
                    icon: Icon(
                      Icons.edit_outlined,
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
                              starred: starred,
                            );
                            widget.onUpdate(localContact);
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
                              starred: starred,
                            );
                            widget.onUpdate(localContact);
                          });
                        },
                        showSuccessMessage:
                            !starred
                                ? 'Contact starred!'
                                : 'Contact unstarred!',
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
