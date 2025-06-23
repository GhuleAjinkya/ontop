import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../notifications/call_notifs/phone_contacts_service.dart';
import 'contacts_adapter.dart';
import 'class_contacts.dart' as app_contacts;
import '../main.dart';

class ContactImportScreen extends StatefulWidget {
  final VoidCallback onContactsImported;

  const ContactImportScreen({super.key, required this.onContactsImported});

  @override
  State<ContactImportScreen> createState() => _ContactImportScreenState();
}

class _ContactImportScreenState extends State<ContactImportScreen> {
  List<app_contacts.Contact> availableContacts = [];
  Set<String> selectedContactIds = {};
  bool isLoading = true;
  bool isImporting = false;
  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoadContacts();
  }

  Future<void> _requestPermissionAndLoadContacts() async {
    // Proactively request permission on screen load
    await _requestContactsPermission();
    _loadPhoneContacts();
  }

  Future<void> _requestContactsPermission() async {
    try {
      final statuses = await [
        Permission.contacts,
      ].request();
      
      final status = statuses[Permission.contacts];
      print('Proactive permission request status: $status');
    } catch (e) {
      print('Error in proactive permission request: $e');
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPhoneContacts() async {
    setState(() {
      isLoading = true;
    });

    try {
      print('Starting to load phone contacts...');

      // First check if we have permission
      final hasPermission = await PhoneContactsService.hasContactsPermission();
      print('Has permission: $hasPermission');

      final contacts = await PhoneContactsService.getImportableContacts();
      print('Loaded ${contacts.length} contacts successfully');

      setState(() {
        availableContacts = contacts;
        isLoading = false;
      });

      if (contacts.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No contacts found on your device'),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: _loadPhoneContacts,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error loading contacts: $e');
      setState(() {
        isLoading = false;
      });

      if (mounted) {
        String errorMessage = 'Failed to load contacts';
        String actionLabel = 'Retry';
        VoidCallback? actionCallback = _loadPhoneContacts;

        if (e.toString().toLowerCase().contains('permission')) {
          errorMessage =
              'Contacts permission required. Please grant permission and try again.';
          actionLabel = 'Open Settings';
          actionCallback = () async {
            // Try to request permission again
            try {
              final granted =
                  await PhoneContactsService.requestContactsPermission();
              if (granted) {
                _loadPhoneContacts();
              } else {
                // Open app settings
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Please enable contacts permission in your device settings',
                    ),
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            } catch (e) {
              print('Error requesting permission: $e');
            }
          };
        } else if (e.toString().toLowerCase().contains('denied')) {
          errorMessage =
              'Contacts access was denied. Please enable it in your device settings.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: actionLabel,
              onPressed: actionCallback,
            ),
          ),
        );
      }
    }
  }

  List<app_contacts.Contact> get filteredContacts {
    if (searchQuery.isEmpty) return availableContacts;

    return availableContacts.where((contact) {
      return contact.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          contact.phoneNumber.contains(searchQuery);
    }).toList();
  }

  void _toggleSelectAll() {
    setState(() {
      final filtered = filteredContacts;
      if (selectedContactIds.length == filtered.length) {
        // Deselect all
        selectedContactIds.clear();
      } else {
        // Select all filtered contacts
        selectedContactIds.clear();
        selectedContactIds.addAll(filtered.map((c) => c.id.toString()));
      }
    });
  }

  Future<void> _importSelectedContacts() async {
    if (selectedContactIds.isEmpty) return;

    setState(() {
      isImporting = true;
    });

    try {
      final contactsToImport =
          availableContacts
              .where(
                (contact) => selectedContactIds.contains(contact.id.toString()),
              )
              .toList();

      int successCount = 0;
      int failureCount = 0;

      for (final contact in contactsToImport) {
        try {
          final contactData = {
            'name': contact.name,
            'organization': contact.organization,
            'phoneNumber': contact.phoneNumber,
            'position': contact.position,
            'starred': 0,
            'type': 'contact',
            'created_at': DateTime.now(),
          };

          await ContactsAdapter.addContact(contactData);
          successCount++;
        } catch (e) {
          print('Failed to import contact ${contact.name}: $e');
          failureCount++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              successCount > 0
                  ? '$successCount contacts imported successfully${failureCount > 0 ? ', $failureCount failed' : ''}'
                  : 'Failed to import contacts',
            ),
            backgroundColor:
                successCount > 0
                    ? Theme.of(context).colorScheme.tertiary
                    : Theme.of(context).colorScheme.error,
          ),
        );

        if (successCount > 0) {
          widget.onContactsImported();
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import contacts: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isImporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: Text(
          'Import Contacts',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (!isLoading && availableContacts.isNotEmpty)
            TextButton(
              onPressed: isImporting ? null : _toggleSelectAll,
              child: Text(
                selectedContactIds.length == filteredContacts.length
                    ? 'Deselect All'
                    : 'Select All',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.tertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          if (!isLoading && availableContacts.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(16),
              decoration: standardTile(10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: TextField(
                controller: searchController,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                cursorColor: Theme.of(context).colorScheme.tertiary,
                decoration: InputDecoration(
                  hintText: 'Search contacts...',
                  labelText: 'Search',
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondary,
                  ),
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondary,
                  ),
                  border: InputBorder.none,
                  prefixIcon: Icon(
                    Icons.search,
                    color: Theme.of(context).colorScheme.onSecondary,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    searchQuery = value.trim();
                  });
                },
              ),
            ),

          // Selected count
          if (selectedContactIds.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '${selectedContactIds.length} contact${selectedContactIds.length == 1 ? '' : 's'} selected',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.tertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          // Content
          Expanded(
            child:
                isLoading
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading contacts...',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                    : availableContacts.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.contacts_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.onSecondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No contacts found',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Make sure you have contacts in your phone\nand granted permission to access them.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                // Check current permission status
                                final currentStatus =
                                    await Permission.contacts.status;

                                if (currentStatus ==
                                    PermissionStatus.permanentlyDenied) {
                                  // Show dialog to open app settings
                                  _showOpenSettingsDialog();
                                  return;
                                }

                                final granted =
                                    await PhoneContactsService.requestContactsPermission();
                                if (granted) {
                                  _loadPhoneContacts();
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                          'Please grant contacts permission to import your contacts',
                                        ),
                                        backgroundColor:
                                            Theme.of(context).colorScheme.error,
                                        action: SnackBarAction(
                                          label: 'Settings',
                                          onPressed: () => openAppSettings(),
                                        ),
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Error requesting permission: $e',
                                      ),
                                      backgroundColor:
                                          Theme.of(context).colorScheme.error,
                                      action: SnackBarAction(
                                        label: 'Settings',
                                        onPressed: () => openAppSettings(),
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.tertiary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            icon: const Icon(Icons.security),
                            label: const Text('Grant Contacts Permission'),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: filteredContacts.length,
                      itemBuilder: (context, index) {
                        final contact = filteredContacts[index];
                        final isSelected = selectedContactIds.contains(
                          contact.id.toString(),
                        );

                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          decoration: standardTile(10, isSelected: isSelected),
                          child: CheckboxListTile(
                            value: isSelected,
                            onChanged:
                                isImporting
                                    ? null
                                    : (bool? value) {
                                      setState(() {
                                        if (value == true) {
                                          selectedContactIds.add(
                                            contact.id.toString(),
                                          );
                                        } else {
                                          selectedContactIds.remove(
                                            contact.id.toString(),
                                          );
                                        }
                                      });
                                    },
                            title: Text(
                              contact.name,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (contact.phoneNumber.isNotEmpty)
                                  Text(
                                    contact.phoneNumber,
                                    style: TextStyle(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                Text(
                                  '${contact.position} • ${contact.organization}',
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.tertiary,
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                            activeColor: Theme.of(context).colorScheme.tertiary,
                            checkColor: Colors.white,
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton:
          selectedContactIds.isNotEmpty
              ? FloatingActionButton.extended(
                onPressed: isImporting ? null : _importSelectedContacts,
                backgroundColor: Theme.of(context).colorScheme.tertiary,
                foregroundColor: Colors.white,
                icon:
                    isImporting
                        ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                        : const Icon(Icons.download),
                label: Text(
                  isImporting
                      ? 'Importing...'
                      : 'Import ${selectedContactIds.length}',
                ),
              )
              : null,
    );
  }

  void _showOpenSettingsDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Permission Required'),
            content: const Text(
              'Contacts permission has been permanently denied. Please enable it in your device settings to import contacts.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
    );
  }
}
