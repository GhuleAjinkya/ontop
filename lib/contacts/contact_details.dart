// dependencies
import 'dart:ui'; // For ImageFilter
import '../shared/user_session.dart';
import 'contacts_adapter.dart'; // Add our new adapter
import '../shared/error_snackbars.dart';
import '../shared/optimistic_updates.dart'; // Add optimistic updates
import '../projects/projects_adapter.dart'; // Add projects adapter
import 'contact_model.dart';
import '../projects/project_model.dart'; // Add project model
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import 'contact_actions.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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

  bool starred = false;
  bool editingContact = false;
  bool editingNotes = false;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController organizationController = TextEditingController();
  final TextEditingController positionController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController(); 
  final TextEditingController notesController = TextEditingController();
  late Contact localContact;
  List<Project> ongoingProjects = [];
  List<Project> completedProjects = [];
  bool loadingProjects = false;
  String get userId => UserSession().userId ?? '';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          // Purple blob 1 - Top area
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
          // Purple blob 2 - Middle area
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
                              ContactActions.callNumber(localContact.phoneNumber, 
                              () => ErrorSnackbars.whileLaunchingExternalApp(context, "Phone Dialer"),
                              );
                            },
                            icon: Icon(
                              Icons.phone_in_talk_outlined,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              ContactActions.openWhatsApp(
                                localContact.phoneNumber, 
                                () => ErrorSnackbars.whileLaunchingExternalApp(context, "WhatsApp"),
                              );
                            },
                            icon: Icon(
                              FontAwesomeIcons.whatsapp,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              if (localContact.email.isEmpty) {
                                ErrorSnackbars.showErrorSnackbar(context, "No email stored for this contact");
                                return;
                              }
                              ContactActions.openEmail(
                                localContact.email, 
                                () => ErrorSnackbars.whileLaunchingExternalApp(context, "Email Client"),
                              );
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  onPressed: () {
                    _showEditContactDialog();
                  },
                  icon: Icon(
                    Icons.edit,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 30,
                  ),
                ),
                Center(
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
                IconButton(
                  onPressed: () async {
                    if (userId.isEmpty) return; // Use optimistic updates for star toggle
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
