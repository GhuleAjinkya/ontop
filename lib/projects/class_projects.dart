import 'package:flutter/material.dart';
import 'dart:ui';
import 'project_model.dart';
import '../tasks/to_do_item_model.dart';
import '../main.dart';
import '../contacts/class_contacts.dart';
import '../shared/user_session.dart';
import 'projects_adapter.dart';
import '../contacts/contacts_adapter.dart';
import '../shared/optimistic_updates.dart';
import '../shared/dialog_helper.dart';
import '../shared/date_formatter.dart';
import '../tasks/project_tasks_sync.dart';
import '../contacts/contact_model.dart';

class Projects extends StatefulWidget {
  const Projects({super.key, this.initialProject});

  final Project? initialProject;

  @override
  State<Projects> createState() => _ProjectsState();
}

class _ProjectsState extends State<Projects> {
  List<Project> projects = [];
  bool addingProject = false;
  bool searching = false;
  bool fetchingProjects = false;
  String searchQuery = '';
  String selectedTab = 'Ongoing'; // Add tab state - default to Ongoing
  TextEditingController projectTitle = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  Project? openedProject;
  String get userId => UserSession().userId ?? '';
  List<Contact> globalContacts = []; // For collaborator name mapping
  @override
  void initState() {
    super.initState();
    print("Called Projects initState");
    loadProjects();
    loadContactsFromMongo();

    // Set initial project if provided
    if (widget.initialProject != null) {
      openedProject = widget.initialProject;
    }
  }

  Future<void> loadContactsFromMongo() async {
    String userId = UserSession().userId ?? '';
    if (userId.isEmpty) {
      print("No user ID available. Cannot load contacts.");
      globalContacts = [];
      return;
    }

    try {
      // Use ContactsAdapter instead of direct MongoDB access
      List<Map<String, dynamic>> fetchedContacts =
          await ContactsAdapter.getContacts();
      globalContacts =
          fetchedContacts.map((doc) => Contact.fromMongo(doc)).toList();
      print(
        "Successfully loaded ${globalContacts.length} contacts for project collaborators",
      );
      setState(() {});
    } catch (e) {
      print("Error loading contacts for project: $e");
      globalContacts = [];
      setState(() {});
    }
  }

  Future<void> loadProjects() async {
    if (userId.isEmpty) {
      print("No user ID available. Cannot load projects.");
      projects = [];
      return;
    }

    try {
      setState(() {
        fetchingProjects = true;
      });
      List<Map<String, dynamic>> fetchedProjects =
          await ProjectsAdapter.getProjects();

      // Convert documents to Project objects
      projects = fetchedProjects.map((doc) => Project.fromMongo(doc)).toList();

      print("Successfully loaded ${projects.length} projects for user $userId");
      setState(() {
        fetchingProjects = false;
      });
    } catch (e) {
      print("Error loading projects: $e");
      projects = [];

      if (mounted) {
        setState(() {
          fetchingProjects = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load projects: $e'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Enhanced project tiles builder based on Figma design
  Widget buildEnhancedProjectTiles(List<Project> allProjects) {
    // Filter projects based on search query if searching
    List<Project> filteredProjects = allProjects;

    if (searching && searchQuery.isNotEmpty) {
      filteredProjects =
          allProjects.where((project) {
            // Search in project title, description, and collaborator names
            final titleMatch = project.title.toLowerCase().contains(
              searchQuery.toLowerCase(),
            );
            final descriptionMatch = project.description.toLowerCase().contains(
              searchQuery.toLowerCase(),
            );

            // Search in collaborator names
            final collaboratorMatch = project.collaborators.any((phone) {
              final contact = globalContacts.firstWhere(
                (c) => c.phoneNumber == phone,
                orElse:
                    () => Contact(
                      id: 0,
                      name: "Unknown",
                      organization: "",
                      phoneNumber: phone,
                      position: "",
                      starred: false,
                    ),
              );
              return contact.name.toLowerCase().contains(
                searchQuery.toLowerCase(),
              );
            });

            return titleMatch || descriptionMatch || collaboratorMatch;
          }).toList();
    }

    // Filter projects based on selected tab (Ongoing vs Completed)
    List<Project> tabFilteredProjects;
    if (selectedTab == 'Ongoing') {
      tabFilteredProjects =
          filteredProjects.where((p) => p.isCompleted != true).toList();
    } else {
      tabFilteredProjects =
          filteredProjects.where((p) => p.isCompleted == true).toList();
    }

    // Sort projects: for completed projects, show recently completed first
    // For ongoing projects, sort by creation date (most recent first)
    tabFilteredProjects.sort((a, b) {
      if (selectedTab == 'Completed') {
        // For completed projects, prioritize:
        // 1. Recently checked off (isCompleted true but completedAt null)
        // 2. Most recently completed (by completedAt)
        // 3. Fall back to creation date if needed
        if (a.isCompleted == true &&
            a.completedAt == null &&
            b.isCompleted == true &&
            b.completedAt != null) {
          return -1; // a was just checked off, should come before b
        }
        if (a.isCompleted == true &&
            a.completedAt != null &&
            b.isCompleted == true &&
            b.completedAt == null) {
          return 1; // b was just checked off, should come before a
        }
        if (a.completedAt == null && b.completedAt == null) {
          // If both don't have completedAt, fall back to creation date
          if (a.createdAt == null && b.createdAt == null) return 0;
          if (a.createdAt == null) return 1;
          if (b.createdAt == null) return -1;
          return b.createdAt!.compareTo(a.createdAt!);
        }
        if (a.completedAt == null) return 1;
        if (b.completedAt == null) return -1;
        return b.completedAt!.compareTo(a.completedAt!);
      } else {
        // For ongoing projects, sort by creation date (most recent first)
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      }
    });

    // If no projects found for the selected tab, show empty state
    if (tabFilteredProjects.isEmpty) {
      return Center(
        child: Container(
          margin: EdgeInsets.only(top: 50),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              !addingProject
                  ? fetchingProjects
                      ? CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.tertiary,
                      )
                      : Icon(
                        Icons.folder_outlined,
                        size: 80,
                        color: Theme.of(context).colorScheme.tertiary,
                      )
                  : Container(),
              SizedBox(height: 16),
              Text(
                // summary: if adding a project, show nothing. if not, then if fetching
                // project, show fetching projects
                !addingProject
                    ? fetchingProjects
                        ? "Fetching Projects..."
                        : selectedTab == 'Ongoing'
                        ? (searching && searchQuery.isNotEmpty
                            ? 'No ongoing projects found'
                            : 'No ongoing projects')
                        : (searching && searchQuery.isNotEmpty
                            ? 'No completed projects found'
                            : 'No completed projects')
                    : "",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.tertiary,
                  fontSize: 18,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              if (!searching &&
                  selectedTab == 'Ongoing' &&
                  !fetchingProjects) ...[
                SizedBox(height: 8),
                Text(
                  !addingProject
                      ? 'Tap the + button to add your first project'
                      : '',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.tertiary.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontFamily: 'Poppins',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 20),
      itemCount: tabFilteredProjects.length,
      itemBuilder: (context, index) {
        final project = tabFilteredProjects[index];

        // Get collaborators display text using NAMES instead of phone numbers
        String collaboratorsText =
            project.collaborators.isEmpty
                ? "No collaborators"
                : "Collaborators: ${project.collaborators.map((phone) {
                  final contact = globalContacts.firstWhere((c) => c.phoneNumber == phone, orElse: () => Contact(id: 0, name: "Unknown", organization: "", phoneNumber: phone, position: "", starred: false));
                  return contact.name;
                }).take(2).join(", ")}${project.collaborators.length > 2 ? "..." : ""}";

        // Get description display text
        String descriptionText =
            project.description.isEmpty
                ? "No description"
                : "Description: ${project.description.length > 40 ? "${project.description.substring(0, 40)}..." : project.description}";

        // Get formatted creation date
        String creationDate = "";
        String completionDate = "";
        try {
          if (project.createdAt != null) {
            final date = project.createdAt!;
            final months = [
              '',
              'January',
              'February',
              'March',
              'April',
              'May',
              'June',
              'July',
              'August',
              'September',
              'October',
              'November',
              'December',
            ];
            creationDate = "${date.day} ${months[date.month]}, ${date.year}";
          }

          // Add completion date if project is completed
          if (project.isCompleted == true && project.completedAt != null) {
            final date = project.completedAt!;
            final months = [
              '',
              'January',
              'February',
              'March',
              'April',
              'May',
              'June',
              'July',
              'August',
              'September',
              'October',
              'November',
              'December',
            ];
            completionDate = "${date.day} ${months[date.month]}, ${date.year}";
          }
        } catch (e) {
          creationDate = "Date unknown";
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          child: Stack(
            children: [
              // Main project tile with Events tab style decoration
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(
                      minHeight: 179, // Minimum height
                    ),
                    decoration: BoxDecoration(
                      color:
                          (project.isCompleted == true)
                              ? Theme.of(
                                context,
                              ).colorScheme.onPrimary.withValues(alpha: 0.05)
                              : Theme.of(
                                context,
                              ).colorScheme.onPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color:
                            (project.isCompleted == true)
                                ? Theme.of(
                                  context,
                                ).colorScheme.onPrimary.withValues(alpha: 0.1)
                                : Theme.of(
                                  context,
                                ).colorScheme.onPrimary.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(15),
                        onTap: () {
                          setState(() {
                            openedProject = project;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(25),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Project title with Figma styling
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title row with checkbox
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: Text(
                                          project.title,
                                          style: TextStyle(
                                            color:
                                                (project.isCompleted == true)
                                                    ? Colors.white60
                                                    : Colors.white,
                                            fontSize: 24,
                                            fontFamily: 'Poppins',
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          softWrap: true,
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 12,
                                      ), // Functional checkbox for project completion status (top right)
                                      Flexible(
                                        flex: 0,
                                        child: GestureDetector(
                                          onTap: () async {
                                            // Toggle project completion status using optimistic updates
                                            final newCompletionStatus =
                                                project.isCompleted != true;
                                            final now = DateTime.now();

                                            await OptimisticUpdates.performItemUpdate<
                                              Project
                                            >(
                                              list: projects,
                                              findItem:
                                                  (p) => p.id == project.id,
                                              updateItem:
                                                  (p) => p.copyWith(
                                                    isCompleted:
                                                        newCompletionStatus,
                                                    completedAt:
                                                        newCompletionStatus
                                                            ? now
                                                            : null,
                                                  ),
                                              databaseOperation: () async {
                                                final updatedProject = project
                                                    .copyWith(
                                                      isCompleted:
                                                          newCompletionStatus,
                                                      completedAt:
                                                          newCompletionStatus
                                                              ? now
                                                              : null,
                                                    );
                                                final projectData =
                                                    updatedProject.toMap();
                                                projectData['_id'] = project.id;

                                                return await ProjectsAdapter.updateProject(
                                                  projectData,
                                                );
                                              },
                                              showSuccessMessage:
                                                  newCompletionStatus
                                                      ? 'Project "${project.title}" marked as completed!'
                                                      : 'Project "${project.title}" marked as incomplete!',
                                              showErrorMessage:
                                                  'Failed to update project status',
                                              context: context,
                                              onSuccess: () {
                                                setState(
                                                  () {},
                                                ); // Trigger rebuild to update UI
                                              },
                                              onError: (error) {
                                                setState(
                                                  () {},
                                                ); // Trigger rebuild to revert UI
                                              },
                                            );
                                          },
                                          child: Container(
                                            width: 26,
                                            height: 26,
                                            decoration: BoxDecoration(
                                              color:
                                                  (project.isCompleted == true)
                                                      ? const Color(0xFFF2F2F2)
                                                      : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: const Color(0xFFF2F2F2),
                                                width: 2,
                                              ),
                                            ),
                                            child:
                                                (project.isCompleted == true)
                                                    ? const Icon(
                                                      Icons.check,
                                                      size: 16,
                                                      color: Color(0xFF1A1A1A),
                                                    )
                                                    : null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Creation date under the title
                                  if (creationDate.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      "Created: $creationDate",
                                      style: TextStyle(
                                        color:
                                            (project.isCompleted == true)
                                                ? Colors.white.withValues(
                                                  alpha: 0.4,
                                                )
                                                : Colors.white70,
                                        fontSize: 12,
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                  // Completion date for completed projects
                                  if (project.isCompleted == true &&
                                      completionDate.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      "Completed: $completionDate",
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.5,
                                        ),
                                        fontSize: 12,
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ],
                              ),

                              const SizedBox(height: 20),

                              // Collaborators text with Figma styling
                              Text(
                                collaboratorsText,
                                style: TextStyle(
                                  color:
                                      (project.isCompleted == true)
                                          ? Colors.white60
                                          : Colors.white,
                                  fontSize: 14,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),

                              const SizedBox(height: 4),

                              // Description text with Figma styling
                              Text(
                                descriptionText,
                                style: TextStyle(
                                  color:
                                      (project.isCompleted == true)
                                          ? Colors.white60
                                          : Colors.white,
                                  fontSize: 14,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),

                              // Add some bottom padding to ensure delete button doesn't overlap
                              const SizedBox(height: 45),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Delete button positioned at bottom right with tertiary color
              Positioned(
                bottom: 25, // Same distance from bottom as checkbox is from top
                right: 25, // Moved a bit more to the left
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.tertiary.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: () async {
                      // Show confirmation dialog for project deletion
                      DialogHelper.showDeleteConfirmation(
                        context: context,
                        title: 'Delete Project?',
                        content:
                            'Project "${project.title}" will be permanently deleted.',
                        onDelete: () async {
                          // Use optimistic updates for project deletion
                          await OptimisticUpdates.performListOperation<Project>(
                            list: projects,
                            operation: 'remove',
                            item: project,
                            databaseOperation: () async {
                              return await ProjectsAdapter.deleteProject(
                                project.id!,
                              );
                            },
                            showSuccessMessage:
                                'Project "${project.title}" deleted successfully',
                            showErrorMessage: 'Failed to delete project',
                            context: context,
                            onSuccess: () {
                              // Sync project deletion to Tasks tab
                              ProjectTasksSync.removeProjectFromTasks(
                                project.id.toString(),
                              );
                              setState(() {}); // Trigger rebuild
                            },
                            onError: (error) {
                              setState(
                                () {},
                              ); // Trigger rebuild to restore deleted item                            print('Error deleting project: $error');
                            },
                          );
                        },
                      );
                    },
                    icon: Icon(
                      Icons.delete,
                      color: Theme.of(context).colorScheme.primary,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showProjectDialog({Project? project}) {
    final isEditing = project != null;
    final titleController = TextEditingController(text: project?.title ?? '');
    final descriptionController = TextEditingController(
      text: project?.description ?? '',
    );

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
              isEditing ? 'Edit Project' : 'Add New Project',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogTextField(
                    controller: titleController,
                    label: 'Project Title',
                    hint: 'Enter project title',
                  ),
                  SizedBox(height: 16),
                  _buildDialogTextField(
                    controller: descriptionController,
                    label: 'Description (Optional)',
                    hint: 'Enter project description',
                    maxLines: 3,
                  ),
                ],
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
                    () => _saveProject(
                      project: project,
                      title: titleController.text,
                      description: descriptionController.text,
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
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
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

  void _saveProject({
    Project? project,
    required String title,
    required String description,
  }) async {
    if (title.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Project title is required')));
      return;
    }

    if (userId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please log in to save projects')));
      return;
    }

    Navigator.pop(context);

    final now = DateTime.now();
    final projectData = {
      'title': title.trim(),
      'description': description.trim(),
      'collaborators': project?.collaborators ?? [],
      'project_tasks':
          project?.projectTasks.map((task) => task.toMap()).toList() ?? [],
      'type': 'project',
      'created_at':
          project?.createdAt?.toIso8601String() ?? now.toIso8601String(),
    };

    // Create temporary project for optimistic update
    final tempProject = Project(
      id: project?.id ?? now.millisecondsSinceEpoch.toString(),
      title: projectData['title'] as String,
      description: projectData['description'] as String,
      collaborators: List<dynamic>.from(projectData['collaborators'] as List),
      projectTasks: project?.projectTasks ?? [],
      createdAt: project?.createdAt ?? now,
      isCompleted: project?.isCompleted ?? false,
    );

    bool success;
    if (project != null) {
      // Update existing project
      success = await ProjectsAdapter.updateProject({
        '_id': project.id,
        ...projectData,
      });
    } else {
      // Create new project
      await OptimisticUpdates.performListOperation<Project>(
        list: projects,
        operation: 'add',
        item: tempProject,
        databaseOperation: () async {
          return await ProjectsAdapter.addProject(projectData);
        },
        showSuccessMessage: 'Project added successfully!',
        showErrorMessage: 'Failed to add project',
        context: context,
        onSuccess: () async {
          await loadProjects();
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
      ).showSnackBar(SnackBar(content: Text('Project updated successfully')));
      await loadProjects();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save project')));
    }
  }

  // Helper method to build tab chips with Events-style design
  Widget _buildTabChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12), // Match Events exactly
        decoration: BoxDecoration(
          color:
              isSelected
                  ? Colors.grey[700]
                  : Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color:
                isSelected
                    ? Colors.grey[700]!
                    : Theme.of(context).colorScheme.tertiary.withValues(
                      alpha: 0.3,
                    ), // Light purple
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color:
                  isSelected
                      ? Colors.white
                      : Theme.of(context).colorScheme.tertiary, // Light purple
              fontWeight: FontWeight.w500,
              fontFamily: 'Poppins',
              fontSize: 14, // Match Events exactly
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (openedProject != null) {
      return ProjectDetails(
        project: openedProject!,
        onBack: () async {
          setState(() {
            openedProject = null;
          });
        },
        onUpdate: (updatedProject) {
          setState(() {
            final idx = projects.indexWhere((p) => p.id == updatedProject.id);
            if (idx != -1) {
              projects[idx] = updatedProject;
            }
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
            // Purple blob 1 - Top right area (mirrored from contacts' top left)
            Positioned(
              top: 80,
              right: 10, // Mirrored: was left: 10 in contacts
              child: Container(
                width: 140,
                height: 200,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary.withValues(
                    alpha: 0.6,
                  ), // Same as contacts
                  borderRadius: BorderRadius.circular(100),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 60, sigmaY: 45),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            // Purple blob 2 - Middle left area (mirrored from contacts' middle right)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.4,
              left: -50, // Mirrored: was right: -50 in contacts
              child: Container(
                width: 170,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.secondary.withValues(
                    alpha: 0.5,
                  ), // Same as contacts
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            // Purple blob 3 - Bottom center area (mirrored horizontally from contacts)
            Positioned(
              bottom: -60,
              right:
                  MediaQuery.of(context).size.width *
                  0.3, // Mirrored: was left in contacts
              child: Container(
                width: 150,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.secondary.withValues(
                    alpha: 0.4,
                  ), // Same as contacts
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            // Purple blob 4 - Middle center left, mirrored from contacts fourth blob! 🌀
            Positioned(
              top: MediaQuery.of(context).size.height * 0.6,
              right:
                  MediaQuery.of(context).size.width * 0.15, // Mirrored position
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
            // Purple blob 5 - Upper middle for extra symmetrical magic! ✨
            Positioned(
              top: MediaQuery.of(context).size.height * 0.15,
              left: MediaQuery.of(context).size.width * 0.5 - 40, // Centered
              child: Container(
                width: 80,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.secondary.withValues(
                    alpha: 0.35,
                  ), // Gentle accent
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 40, sigmaY: 50),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            // Main content
            Container(
              color: Colors.transparent, // Changed from primary to transparent
              child: Column(
                children: [
                  // Enhanced header with Projects title and action buttons
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
                                    'Projects',
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
                                  right: 10,
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
                                          hintText: 'Search projects...',
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
                          Container(
                            margin: EdgeInsets.only(
                              right: 20,
                            ), // Consistent margin with other pages
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
                                    onPressed: () => _showProjectDialog(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Add project input field
                  if (addingProject) ...[
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
                          onPressed: () {
                            setState(() {
                              projectTitle.clear();
                              addingProject = false;
                            });
                          },
                          icon: Icon(
                            Icons.close,
                            color: Theme.of(context).colorScheme.onPrimary,
                            size: 20,
                          ),
                        ),
                        title: TextField(
                          controller: projectTitle,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                          cursorColor: Theme.of(context).colorScheme.tertiary,
                          decoration: InputDecoration(
                            hintText: 'New Project',
                            labelText: 'New Project',
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSecondary,
                            ),
                            hintStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSecondary,
                            ),
                            border: const UnderlineInputBorder(),
                          ),
                        ),
                        trailing: IconButton(
                          alignment: Alignment.centerRight,
                          onPressed: () async {
                            if (projectTitle.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Project title is required'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              return;
                            }

                            if (userId.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Please log in to create projects',
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              return;
                            }
                            final projectTitleText = projectTitle.text.trim();
                            final now = DateTime.now();
                            // Create temporary project for optimistic update
                            final tempProject = Project(
                              id:
                                  now.millisecondsSinceEpoch
                                      .toString(), // Temporary ID
                              title: projectTitleText,
                              description: '',
                              collaborators: [],
                              projectTasks: [],
                              createdAt: now,
                              isCompleted: false,
                            );

                            // Clear form immediately
                            setState(() {
                              addingProject = false;
                            });
                            projectTitle.clear();

                            // Use optimistic updates for project creation
                            await OptimisticUpdates.performListOperation<
                              Project
                            >(
                              list: projects,
                              operation: 'add',
                              item: tempProject,
                              databaseOperation: () async {
                                // Create project data for database
                                final projectData = {
                                  'title': projectTitleText,
                                  'description': '',
                                  'collaborators': [],
                                  'project_tasks': [],
                                  'type': 'project',
                                  'created_at': now.toIso8601String(),
                                };

                                // Insert using our adapter
                                return await ProjectsAdapter.addProject(
                                  projectData,
                                );
                              },
                              showSuccessMessage:
                                  'Project created successfully!',
                              showErrorMessage: 'Failed to create project',
                              context: context,
                              onSuccess: () async {
                                // Reload projects to get the real project with database ID
                                await loadProjects();
                              },
                              onError: (error) {
                                setState(
                                  () {},
                                ); // Trigger rebuild to remove optimistic project
                                print('Error creating project: $error');
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

                  // Tab selector for Ongoing vs Completed projects (exact copy from Events)
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTabChip(
                            label: "Ongoing",
                            isSelected: selectedTab == 'Ongoing',
                            onTap: () {
                              setState(() {
                                selectedTab = 'Ongoing';
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildTabChip(
                            label: "Completed",
                            isSelected: selectedTab == 'Completed',
                            onTap: () {
                              setState(() {
                                selectedTab = 'Completed';
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Enhanced project tiles list
                  Expanded(child: buildEnhancedProjectTiles(projects)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProjectDetails extends StatefulWidget {
  const ProjectDetails({
    super.key,
    required this.project,
    required this.onBack,
    required this.onUpdate,
  });
  final Project project;
  final VoidCallback onBack;
  final ValueChanged<Project> onUpdate;
  @override
  State<ProjectDetails> createState() => _ProjectDetailsState();
}

class _ProjectDetailsState extends State<ProjectDetails> {
  late Project project = widget.project;
  bool expandDescription = true;
  bool editingDescription = false;
  bool expandCollaborators = true;
  bool editingCollaborators = false;
  bool expandToDo = true;
  bool editingToDo = false;
  bool openCompletedTasks = false;
  bool contactsFetched = false;
  bool fetchingContacts = false;
  List<String> completedTasks = [];
  List<String> completedTasksHistory = []; // Track order of task completion
  TextEditingController descriptionController = TextEditingController();
  TextEditingController textController = TextEditingController();
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  List<Contact> globalContacts = [];
  Contact? openedContact;

  Future<void> loadContactsFromMongo() async {
    String userId = UserSession().userId ?? '';
    if (userId.isEmpty) {
      print("No user ID available. Cannot load contacts.");
      globalContacts = [];
      return;
    }

    try {
      setState(() {
        fetchingContacts = true;
      });
      // Use ContactsAdapter instead of direct MongoDB access
      List<Map<String, dynamic>> fetchedContacts =
          await ContactsAdapter.getContacts();
      globalContacts =
          fetchedContacts.map((doc) => Contact.fromMongo(doc)).toList();
      print(
        "Successfully loaded ${globalContacts.length} contacts for project collaborators",
      );
      setState(() {
        fetchingContacts = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          fetchingContacts = false;
        });
      }
      print("Error loading contacts for project: $e");
      globalContacts = [];
    }
  }

  @override
  void initState() {
    super.initState();
    descriptionController = TextEditingController(text: project.description);
    loadContactsFromMongo();
    // Initialize completed tasks from the project data
    if (project.completedTasks != null) {
      completedTasks = List<String>.from(project.completedTasks!);
    }
    // Initialize completion history from project data
    if (project.completedTasksHistory != null) {
      completedTasksHistory = List<String>.from(project.completedTasksHistory!);
    }
  }

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }

  Widget singleFilterChip({
    required String label,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor:
            isSelected ? Colors.white.withAlpha(100) : Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(
            color: Theme.of(context).colorScheme.onPrimary.withAlpha(100),
            width: 2,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }

  Widget divLine() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      height: 3,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            width: 1.25,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }

  void _showTaskDialog() {
    final taskController = TextEditingController();
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
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
                    'Add New Task',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildDialogTextField(
                          controller: taskController,
                          label: 'Task Details',
                          hint: 'Enter task details',
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                icon: Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                                label: Text(
                                  selectedDate != null
                                      ? DateFormatter.formatDate(selectedDate!)
                                      : "Pick date",
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                    fontSize: 12,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                onPressed: () async {
                                  final now = DateTime.now();
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedDate ?? now,
                                    firstDate: now,
                                    lastDate: DateTime(now.year + 5),
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      selectedDate = picked;
                                    });
                                  }
                                },
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: TextButton.icon(
                                icon: Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                                label: Text(
                                  selectedTime != null
                                      ? DateFormatter.formatTimeOfDay(
                                        selectedTime!,
                                      )
                                      : "Pick time",
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                    fontSize: 12,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                onPressed: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime:
                                        selectedTime ?? TimeOfDay.now(),
                                    initialEntryMode: TimePickerEntryMode.dial,
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      selectedTime = picked;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
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
                          () => _saveTask(
                            taskText: taskController.text,
                            selectedDate: selectedDate,
                            selectedTime: selectedTime,
                          ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.secondary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                      ),
                      child: Text(
                        'Add',
                        style: TextStyle(fontFamily: 'Poppins'),
                      ),
                    ),
                  ],
                ),
          ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
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

  void _saveTask({
    required String taskText,
    required DateTime? selectedDate,
    required TimeOfDay? selectedTime,
  }) async {
    if (taskText.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Task details are required')));
      return;
    }

    if (selectedDate == null || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select both date and time')),
      );
      return;
    }

    Navigator.pop(context);

    final newTask = ToDoItem(
      text: taskText.trim(),
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      deadlineDate: DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      ),
    );

    setState(() {
      project.projectTasks.add(newTask);
    });

    // Update project in database
    try {
      final updatedProject = project.copyWith(
        projectTasks: project.projectTasks,
      );
      final projectData = updatedProject.toMap();
      projectData['_id'] = updatedProject.id;

      bool success = await ProjectsAdapter.updateProject(projectData);
      if (success) {
        widget.onUpdate(updatedProject);

        // Sync to Tasks tab
        await ProjectTasksSync.syncProjectToTasks(updatedProject);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task added successfully!'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Revert the local change if database update failed
        setState(() {
          project.projectTasks.removeLast();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to add task'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error updating project tasks: $e');
      // Revert the local change if database update failed
      setState(() {
        project.projectTasks.removeLast();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding task: $e'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If a contact is opened, show ContactDetails inline
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
            final idx = globalContacts.indexWhere(
              (c) => c.id.toString() == updatedContact.id.toString(),
            );
            if (idx != -1) {
              globalContacts[idx] = updatedContact;
              openedContact = updatedContact;
            }
          });
        },
      );
    }

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
          SingleChildScrollView(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Row(
                    // Title and Back Button
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        margin: EdgeInsets.only(left: 10),
                        child: IconButton(
                          onPressed: widget.onBack,
                          icon: Icon(
                            Icons.arrow_back,
                            color: Theme.of(context).colorScheme.onPrimary,
                            size: 30,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          margin: EdgeInsets.only(left: 10, right: 20),
                          child: Text(
                            project.title,
                            textAlign: TextAlign.right,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            softWrap: true,
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    // Description, To-Do, Collaborators
                    decoration: standardTile(40),
                    margin: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    child: Container(
                      margin: EdgeInsets.all(5),
                      child: Column(
                        children: [
                          ListTile(
                            // Description
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Description",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                                if (editingDescription) ...[
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.close,
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onPrimary,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            descriptionController.text =
                                                project.description;
                                            editingDescription = false;
                                          });
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.check,
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onPrimary,
                                        ),
                                        onPressed: () async {
                                          try {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Please wait. Updating Projects...',
                                                ),
                                                duration: Duration(seconds: 1),
                                                showCloseIcon: true,
                                              ),
                                            );
                                            final updatedDescription =
                                                descriptionController.text
                                                    .trim();
                                            final updatedProject = project
                                                .copyWith(
                                                  description:
                                                      updatedDescription,
                                                );

                                            // Update in database - convert to Map for the adapter
                                            final projectData =
                                                updatedProject.toMap();
                                            projectData['_id'] =
                                                updatedProject
                                                    .id; // Ensure the ID is included
                                            bool success =
                                                await ProjectsAdapter.updateProject(
                                                  projectData,
                                                );

                                            if (success) {
                                              setState(() {
                                                project = updatedProject;
                                                editingDescription = false;
                                              });
                                              widget.onUpdate(project);

                                              if (mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Description updated successfully',
                                                    ),
                                                    duration: Duration(
                                                      seconds: 2,
                                                    ),
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
                                                      'Failed to update description',
                                                    ),
                                                    duration: Duration(
                                                      seconds: 2,
                                                    ),
                                                  ),
                                                );
                                              }
                                            }
                                          } catch (e) {
                                            print(
                                              "Error updating project description: $e",
                                            );
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Error updating description: $e',
                                                  ),
                                                  duration: Duration(
                                                    seconds: 2,
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  Container(
                                    margin: EdgeInsets.only(right: 8),
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.edit,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onPrimary,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          editingDescription = true;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: TextField(
                              controller: descriptionController,
                              maxLines: 5,
                              minLines: 1,
                              readOnly: !editingDescription,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: "Write a description...",
                                hintStyle: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSecondary,
                                ),
                                border:
                                    editingDescription
                                        ? OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
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
                                    editingDescription
                                        ? OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
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
                                    editingDescription
                                        ? OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
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
                          ),
                          divLine(),
                          ListTile(
                            // To-Do
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "To-do",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.add,
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                  ),
                                  onPressed: () => _showTaskDialog(),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (editingToDo) ...[
                                  Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 5,
                                    ),
                                    decoration: standardTile(10),
                                    child: ListTile(
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      title: SizedBox(
                                        child: Container(
                                          margin: EdgeInsets.symmetric(
                                            horizontal: 5,
                                          ),
                                          child: TextField(
                                            controller: textController,
                                            style: TextStyle(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onPrimary,
                                            ),
                                            cursorColor:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.tertiary,
                                            decoration: InputDecoration(
                                              hintText: 'Details',
                                              labelText: 'Details*',
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
                                              border:
                                                  const UnderlineInputBorder(),
                                            ),
                                          ),
                                        ),
                                      ),
                                      subtitle: Container(
                                        margin: EdgeInsets.only(top: 10),
                                        child: Column(
                                          children: [
                                            TextButton.icon(
                                              icon: Icon(
                                                Icons.calendar_today,
                                                size: 16,
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.onPrimary,
                                              ),
                                              label: Text(
                                                selectedDate != null
                                                    ? DateFormatter.formatDate(
                                                      selectedDate!,
                                                    )
                                                    : "Pick date",
                                                style: TextStyle(
                                                  color:
                                                      Theme.of(
                                                        context,
                                                      ).colorScheme.onPrimary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              onPressed: () async {
                                                final now = DateTime.now();
                                                final picked =
                                                    await showDatePicker(
                                                      context: context,
                                                      initialDate:
                                                          selectedDate ?? now,
                                                      firstDate: now,
                                                      lastDate: DateTime(
                                                        now.year + 5,
                                                      ),
                                                    );
                                                if (picked != null) {
                                                  setState(() {
                                                    selectedDate = picked;
                                                  });
                                                }
                                              },
                                            ),
                                            TextButton.icon(
                                              icon: Icon(
                                                Icons.access_time,
                                                size: 16,
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.onPrimary,
                                              ),
                                              label: Text(
                                                selectedTime != null
                                                    ? DateFormatter.formatTimeOfDay(
                                                      selectedTime!,
                                                    )
                                                    : "Pick time",
                                                style: TextStyle(
                                                  color:
                                                      Theme.of(
                                                        context,
                                                      ).colorScheme.onPrimary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              onPressed: () async {
                                                final picked =
                                                    await showTimePicker(
                                                      context: context,
                                                      initialTime:
                                                          selectedTime ??
                                                          TimeOfDay.now(),
                                                      initialEntryMode:
                                                          TimePickerEntryMode
                                                              .dial,
                                                    );
                                                if (picked != null) {
                                                  setState(() {
                                                    selectedTime = picked;
                                                  });
                                                }
                                              },
                                            ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceAround,
                                              children: [
                                                IconButton(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  onPressed: () {
                                                    setState(() {
                                                      textController.clear();
                                                      editingToDo = false;
                                                    });
                                                  },
                                                  icon: Icon(
                                                    Icons.close,
                                                    color:
                                                        Theme.of(
                                                          context,
                                                        ).colorScheme.onPrimary,
                                                    size: 20,
                                                  ),
                                                ),
                                                IconButton(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  onPressed: () async {
                                                    if (textController.text
                                                            .trim()
                                                            .isEmpty ||
                                                        selectedDate == null ||
                                                        selectedTime == null) {
                                                      return;
                                                    }

                                                    final newTask = ToDoItem(
                                                      text:
                                                          textController.text
                                                              .trim(),
                                                      id:
                                                          DateTime.now()
                                                              .millisecondsSinceEpoch
                                                              .toString(),
                                                      deadlineDate: DateTime(
                                                        selectedDate!.year,
                                                        selectedDate!.month,
                                                        selectedDate!.day,
                                                        selectedTime!.hour,
                                                        selectedTime!.minute,
                                                      ),
                                                    );

                                                    setState(() {
                                                      project.projectTasks.add(
                                                        newTask,
                                                      );
                                                      textController.clear();
                                                      selectedDate = null;
                                                      selectedTime = null;
                                                      editingToDo = false;
                                                    });

                                                    // Update project in database
                                                    try {
                                                      final updatedProject =
                                                          project.copyWith(
                                                            projectTasks:
                                                                project
                                                                    .projectTasks,
                                                          );
                                                      final projectData =
                                                          updatedProject
                                                              .toMap();
                                                      projectData['_id'] =
                                                          updatedProject.id;

                                                      bool success =
                                                          await ProjectsAdapter.updateProject(
                                                            projectData,
                                                          );
                                                      if (success) {
                                                        widget.onUpdate(
                                                          updatedProject,
                                                        );

                                                        // Sync to Tasks tab
                                                        await ProjectTasksSync.syncProjectToTasks(
                                                          updatedProject,
                                                        );

                                                        if (mounted) {
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).showSnackBar(
                                                            const SnackBar(
                                                              content: Text(
                                                                'Task added successfully!',
                                                              ),
                                                              duration:
                                                                  Duration(
                                                                    seconds: 2,
                                                                  ),
                                                            ),
                                                          );
                                                        }
                                                      } else {
                                                        // Revert the local change if database update failed
                                                        setState(() {
                                                          project.projectTasks
                                                              .removeLast();
                                                        });
                                                        if (mounted) {
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).showSnackBar(
                                                            const SnackBar(
                                                              content: Text(
                                                                'Failed to add task',
                                                              ),
                                                              duration:
                                                                  Duration(
                                                                    seconds: 2,
                                                                  ),
                                                            ),
                                                          );
                                                        }
                                                      }
                                                    } catch (e) {
                                                      print(
                                                        'Error updating project tasks: $e',
                                                      );
                                                      // Revert the local change if database update failed
                                                      setState(() {
                                                        project.projectTasks
                                                            .removeLast();
                                                      });
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              'Error adding task: $e',
                                                            ),
                                                            duration: Duration(
                                                              seconds: 2,
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  },
                                                  icon: Icon(
                                                    Icons.check,
                                                    color:
                                                        Theme.of(
                                                          context,
                                                        ).colorScheme.onPrimary,
                                                    size: 20,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],

                                if (project.projectTasks
                                    .where(
                                      (task) =>
                                          !completedTasks.contains(task.id),
                                    )
                                    .isEmpty) ...[
                                  Container(
                                    margin: EdgeInsets.symmetric(vertical: 10),
                                    child: Text(
                                      project.projectTasks.isEmpty
                                          ? "No tasks yet."
                                          : "All tasks completed!",
                                      style: TextStyle(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSecondary,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  ...project.projectTasks.where((task) => !completedTasks.contains(task.id)).map<
                                    Widget
                                  >((item) {
                                    return Row(
                                      children: [
                                        Checkbox(
                                          value: false,
                                          onChanged: (bool? changed) async {
                                            setState(() {
                                              completedTasks.add(item.id);
                                              // Add to history to track completion order
                                              completedTasksHistory.remove(
                                                item.id,
                                              ); // Remove if already exists
                                              completedTasksHistory.add(
                                                item.id,
                                              ); // Add to end (most recent)
                                            });

                                            // Update project in database with completed tasks and history
                                            try {
                                              final updatedProject = project
                                                  .copyWith(
                                                    projectTasks:
                                                        project.projectTasks,
                                                    completedTasks:
                                                        completedTasks,
                                                    completedTasksHistory:
                                                        completedTasksHistory,
                                                  );
                                              final projectData =
                                                  updatedProject.toMap();
                                              projectData['_id'] =
                                                  updatedProject.id;
                                              projectData['completed_tasks'] =
                                                  completedTasks; // Add completed tasks tracking
                                              projectData['completed_tasks_history'] =
                                                  completedTasksHistory; // Add completion history tracking

                                              bool success =
                                                  await ProjectsAdapter.updateProject(
                                                    projectData,
                                                  );
                                              if (success) {
                                                // Sync to Tasks tab
                                                widget.onUpdate(updatedProject);
                                                await ProjectTasksSync.syncProjectToTasks(
                                                  updatedProject,
                                                );
                                              } else {
                                                // Revert the local change if database update failed
                                                setState(() {
                                                  completedTasks.remove(
                                                    item.id,
                                                  );
                                                  completedTasksHistory.remove(
                                                    item.id,
                                                  );
                                                });
                                                if (mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Failed to update task status',
                                                      ),
                                                      duration: Duration(
                                                        seconds: 2,
                                                      ),
                                                    ),
                                                  );
                                                }
                                              }
                                            } catch (e) {
                                              print(
                                                'Error updating task completion status: $e',
                                              );
                                              // Revert the local change
                                              setState(() {
                                                completedTasks.remove(item.id);
                                                completedTasksHistory.remove(
                                                  item.id,
                                                );
                                              });
                                            }
                                          },
                                          activeColor:
                                              Theme.of(
                                                context,
                                              ).colorScheme.tertiary,
                                          checkColor:
                                              Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                          side: BorderSide(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onPrimary,
                                            width: 1.5,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            item.text,
                                            style: TextStyle(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onPrimary,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        // Add delete button for each task
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete_outline,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimary
                                                .withValues(alpha: 0.7),
                                            size: 20,
                                          ),
                                          onPressed: () async {
                                            // Show confirmation dialog using DialogHelper
                                            DialogHelper.showDeleteConfirmation(
                                              context: context,
                                              title: 'Delete Task?',
                                              content:
                                                  'This task will be permanently deleted.',
                                              onDelete: () async {
                                                // Store original state for rollback
                                                final originalTasks =
                                                    List<ToDoItem>.from(
                                                      project.projectTasks,
                                                    );
                                                final originalCompletedTasks =
                                                    List<String>.from(
                                                      completedTasks,
                                                    );
                                                final originalCompletedTasksHistory =
                                                    List<String>.from(
                                                      completedTasksHistory,
                                                    );

                                                // Remove task from local state
                                                setState(() {
                                                  project.projectTasks
                                                      .removeWhere(
                                                        (task) =>
                                                            task.id == item.id,
                                                      );
                                                  completedTasks.remove(
                                                    item.id,
                                                  ); // Also remove from completed tasks if present
                                                  completedTasksHistory.remove(
                                                    item.id,
                                                  ); // Also remove from history
                                                });

                                                // Update project in database
                                                try {
                                                  final updatedProject = project
                                                      .copyWith(
                                                        projectTasks:
                                                            project
                                                                .projectTasks,
                                                      );
                                                  final projectData =
                                                      updatedProject.toMap();
                                                  projectData['_id'] =
                                                      updatedProject.id;
                                                  projectData['completed_tasks'] =
                                                      completedTasks;
                                                  projectData['completed_tasks_history'] =
                                                      completedTasksHistory;

                                                  bool success =
                                                      await ProjectsAdapter.updateProject(
                                                        projectData,
                                                      );
                                                  if (success) {
                                                    widget.onUpdate(
                                                      updatedProject,
                                                    );
                                                    // Sync to Tasks tab
                                                    await ProjectTasksSync.syncProjectToTasks(
                                                      updatedProject,
                                                    );
                                                    if (mounted) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            'Task deleted successfully',
                                                          ),
                                                          duration: Duration(
                                                            seconds: 2,
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  } else {
                                                    // Revert the local change if database update failed
                                                    setState(() {
                                                      project.projectTasks
                                                          .clear();
                                                      project.projectTasks
                                                          .addAll(
                                                            originalTasks,
                                                          );
                                                      completedTasks.clear();
                                                      completedTasks.addAll(
                                                        originalCompletedTasks,
                                                      );
                                                      completedTasksHistory
                                                          .clear();
                                                      completedTasksHistory.addAll(
                                                        originalCompletedTasksHistory,
                                                      );
                                                    });
                                                    if (mounted) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            'Failed to delete task',
                                                          ),
                                                          duration: Duration(
                                                            seconds: 2,
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  }
                                                } catch (e) {
                                                  print(
                                                    'Error deleting project task: $e',
                                                  );
                                                  // Revert the local change if database update failed
                                                  setState(() {
                                                    project.projectTasks
                                                        .clear();
                                                    project.projectTasks.addAll(
                                                      originalTasks,
                                                    );
                                                    completedTasks.clear();
                                                    completedTasks.addAll(
                                                      originalCompletedTasks,
                                                    );
                                                    completedTasksHistory
                                                        .clear();
                                                    completedTasksHistory.addAll(
                                                      originalCompletedTasksHistory,
                                                    );
                                                  });
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Error deleting task: $e',
                                                        ),
                                                        duration: Duration(
                                                          seconds: 2,
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                }
                                              },
                                            );
                                          },
                                        ),
                                      ],
                                    );
                                  }),
                                ],

                                // Latest Update section (show most recently completed task with undo option)
                                if (completedTasksHistory.isNotEmpty) ...[
                                  Container(
                                    margin: EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 5,
                                    ),
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimary
                                            .withValues(alpha: 0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.update,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onPrimary,
                                              size: 16,
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              "Latest Update",
                                              style: TextStyle(
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.onPrimary,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.tertiary,
                                              size: 18,
                                            ),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Builder(
                                                builder: (context) {
                                                  // Get the most recently completed task
                                                  final latestCompletedId =
                                                      completedTasksHistory
                                                          .last;
                                                  final latestTask = project
                                                      .projectTasks
                                                      .firstWhere(
                                                        (task) =>
                                                            task.id ==
                                                            latestCompletedId,
                                                        orElse:
                                                            () => ToDoItem(
                                                              id: '',
                                                              text:
                                                                  'Task not found',
                                                              deadlineDate:
                                                                  DateTime.now(),
                                                            ),
                                                      );
                                                  return Text(
                                                    'Completed: ${latestTask.text}',
                                                    style: TextStyle(
                                                      color:
                                                          Theme.of(context)
                                                              .colorScheme
                                                              .onPrimary,
                                                      fontSize: 14,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  );
                                                },
                                              ),
                                            ),
                                            // Undo button
                                            IconButton(
                                              icon: Icon(
                                                Icons.undo,
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.tertiary,
                                                size: 18,
                                              ),
                                              onPressed: () async {
                                                if (completedTasksHistory
                                                    .isNotEmpty) {
                                                  final taskToUndo =
                                                      completedTasksHistory
                                                          .last;

                                                  setState(() {
                                                    completedTasks.remove(
                                                      taskToUndo,
                                                    );
                                                    completedTasksHistory
                                                        .remove(taskToUndo);
                                                  });

                                                  // Update database
                                                  try {
                                                    final updatedProject =
                                                        project.copyWith(
                                                          projectTasks:
                                                              project
                                                                  .projectTasks,
                                                          completedTasks:
                                                              completedTasks,
                                                          completedTasksHistory:
                                                              completedTasksHistory,
                                                        );
                                                    final projectData =
                                                        updatedProject.toMap();
                                                    projectData['_id'] =
                                                        updatedProject.id;
                                                    projectData['completed_tasks'] =
                                                        completedTasks;
                                                    projectData['completed_tasks_history'] =
                                                        completedTasksHistory;
                                                    bool success =
                                                        await ProjectsAdapter.updateProject(
                                                          projectData,
                                                        );
                                                    if (!success) {
                                                      // Revert if database update failed
                                                      setState(() {
                                                        completedTasks.add(
                                                          taskToUndo,
                                                        );
                                                        completedTasksHistory
                                                            .add(taskToUndo);
                                                      });
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          const SnackBar(
                                                            content: Text(
                                                              'Failed to undo task completion',
                                                            ),
                                                            duration: Duration(
                                                              seconds: 2,
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    } else {
                                                      // Sync undo completion to Tasks tab
                                                      await ProjectTasksSync.syncProjectToTasks(
                                                        updatedProject,
                                                      );
                                                      widget.onUpdate(
                                                        updatedProject,
                                                      );
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          const SnackBar(
                                                            content: Text(
                                                              'Task completion undone',
                                                            ),
                                                            duration: Duration(
                                                              seconds: 2,
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  } catch (e) {
                                                    print(
                                                      'Error undoing task completion: $e',
                                                    );
                                                    // Revert the local change
                                                    setState(() {
                                                      completedTasks.add(
                                                        taskToUndo,
                                                      );
                                                      completedTasksHistory.add(
                                                        taskToUndo,
                                                      );
                                                    });
                                                  }
                                                }
                                              },
                                              tooltip: 'Undo completion',
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          divLine(),
                          ListTile(
                            // Collabs
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  fetchingContacts
                                      ? "Fetching..."
                                      : "Collaborators",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.add,
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                  ),
                                  onPressed: () async {
                                    final selectedContacts = await showDialog<
                                      List<Contact>
                                    >(
                                      context: context,
                                      builder: (context) {
                                        String search = '';
                                        List<Contact> filtered = globalContacts;
                                        List<Contact> selectedContacts = [];
                                        TextEditingController searchController =
                                            TextEditingController();
                                        bool fetchingContacts = false;
                                        int loop = 0;
                                        return StatefulBuilder(
                                          builder: (context, setDialogState) {
                                            // Filter contacts by search query with improved ordering
                                            if (globalContacts.isEmpty &&
                                                contactsFetched == false) {
                                              loop += 1;
                                              print("loops = $loop\n");
                                              setDialogState(() {
                                                fetchingContacts = true;
                                              });
                                              loadContactsFromMongo().then((_) {
                                                setDialogState(() {
                                                  filtered = globalContacts;
                                                  fetchingContacts = false;
                                                  contactsFetched = true;
                                                });
                                              });
                                            } else {
                                              filtered =
                                                  globalContacts
                                                      .where(
                                                        (c) =>
                                                            c.name
                                                                .toLowerCase()
                                                                .contains(
                                                                  search
                                                                      .toLowerCase(),
                                                                ) ||
                                                            c.phoneNumber
                                                                .toLowerCase()
                                                                .contains(
                                                                  search
                                                                      .toLowerCase(),
                                                                ),
                                                      )
                                                      .toList();
                                            }

                                            // Sort filtered contacts: starts with query first, then contains query
                                            if (search.isNotEmpty) {
                                              filtered.sort((a, b) {
                                                final aNameStartsWith = a.name
                                                    .toLowerCase()
                                                    .startsWith(
                                                      search.toLowerCase(),
                                                    );
                                                final bNameStartsWith = b.name
                                                    .toLowerCase()
                                                    .startsWith(
                                                      search.toLowerCase(),
                                                    );
                                                final aPhoneStartsWith = a
                                                    .phoneNumber
                                                    .toLowerCase()
                                                    .startsWith(
                                                      search.toLowerCase(),
                                                    );
                                                final bPhoneStartsWith = b
                                                    .phoneNumber
                                                    .toLowerCase()
                                                    .startsWith(
                                                      search.toLowerCase(),
                                                    );

                                                final aStartsWith =
                                                    aNameStartsWith ||
                                                    aPhoneStartsWith;
                                                final bStartsWith =
                                                    bNameStartsWith ||
                                                    bPhoneStartsWith;

                                                if (aStartsWith &&
                                                    !bStartsWith) {
                                                  return -1;
                                                }
                                                if (!aStartsWith &&
                                                    bStartsWith) {
                                                  return 1;
                                                }

                                                // If both start with query, prioritize name matches over phone matches
                                                if (aStartsWith &&
                                                    bStartsWith) {
                                                  if (aNameStartsWith &&
                                                      !bNameStartsWith) {
                                                    return -1;
                                                  }
                                                  if (!aNameStartsWith &&
                                                      bNameStartsWith) {
                                                    return 1;
                                                  }
                                                }

                                                return a.name.compareTo(b.name);
                                              });
                                            }

                                            return AlertDialog(
                                              backgroundColor:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                side: BorderSide(
                                                  color:
                                                      Theme.of(
                                                        context,
                                                      ).colorScheme.onPrimary,
                                                  width: 1,
                                                ),
                                              ),
                                              title: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    'Add Collaborators',
                                                    style: TextStyle(
                                                      color:
                                                          Theme.of(context)
                                                              .colorScheme
                                                              .onPrimary,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  if (selectedContacts
                                                      .isNotEmpty)
                                                    Container(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Theme.of(context)
                                                                .colorScheme
                                                                .tertiary,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        '${selectedContacts.length}',
                                                        style: TextStyle(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .primary,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              content: SizedBox(
                                                width: 300,
                                                height: 400,
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    TextField(
                                                      controller:
                                                          searchController,
                                                      maxLines: 1,
                                                      style: TextStyle(
                                                        color:
                                                            Theme.of(context)
                                                                .colorScheme
                                                                .onPrimary,
                                                      ),
                                                      decoration: InputDecoration(
                                                        labelText:
                                                            "Search in Contacts",
                                                        labelStyle: TextStyle(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .tertiary,
                                                        ),
                                                        hintStyle: TextStyle(
                                                          color: Theme.of(
                                                                context,
                                                              )
                                                              .colorScheme
                                                              .tertiary
                                                              .withValues(
                                                                alpha: 0.7,
                                                              ),
                                                        ),
                                                        enabledBorder:
                                                            OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                              borderSide: BorderSide(
                                                                color: Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .tertiary
                                                                    .withValues(
                                                                      alpha:
                                                                          0.3,
                                                                    ),
                                                              ),
                                                            ),
                                                        focusedBorder: OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                          borderSide: BorderSide(
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .secondary,
                                                            width: 2,
                                                          ),
                                                        ),
                                                      ),
                                                      onChanged: (val) {
                                                        setDialogState(() {
                                                          search = val;
                                                        });
                                                      },
                                                    ),
                                                    SizedBox(height: 16),
                                                    Expanded(
                                                      child:
                                                          fetchingContacts
                                                              ? Container(
                                                                margin:
                                                                    EdgeInsets.only(
                                                                      top: 75,
                                                                    ),
                                                                child: Text(
                                                                  "Fetching Contacts...",
                                                                  style: TextStyle(
                                                                    color:
                                                                        Theme.of(
                                                                          context,
                                                                        ).colorScheme.tertiary,
                                                                  ),
                                                                ),
                                                              )
                                                              : filtered.isEmpty
                                                              ? Container(
                                                                margin:
                                                                    EdgeInsets.only(
                                                                      top: 75,
                                                                    ),
                                                                child: Text(
                                                                  "No contacts found.",
                                                                  style: TextStyle(
                                                                    color:
                                                                        Theme.of(
                                                                          context,
                                                                        ).colorScheme.tertiary,
                                                                  ),
                                                                ),
                                                              )
                                                              : ListView.builder(
                                                                itemCount:
                                                                    filtered
                                                                        .length,
                                                                itemBuilder: (
                                                                  context,
                                                                  index,
                                                                ) {
                                                                  final contact =
                                                                      filtered[index];
                                                                  final alreadyAdded = project
                                                                      .collaborators
                                                                      .any(
                                                                        (c) =>
                                                                            c ==
                                                                            contact.phoneNumber,
                                                                      );
                                                                  final isSelected =
                                                                      selectedContacts.any(
                                                                        (c) =>
                                                                            c.phoneNumber ==
                                                                            contact.phoneNumber,
                                                                      );

                                                                  return CheckboxListTile(
                                                                    value:
                                                                        isSelected,
                                                                    onChanged:
                                                                        alreadyAdded
                                                                            ? null
                                                                            : (
                                                                              bool?
                                                                              checked,
                                                                            ) {
                                                                              setDialogState(
                                                                                () {
                                                                                  if (checked ==
                                                                                      true) {
                                                                                    selectedContacts.add(
                                                                                      contact,
                                                                                    );
                                                                                  } else {
                                                                                    selectedContacts.removeWhere(
                                                                                      (
                                                                                        c,
                                                                                      ) =>
                                                                                          c.phoneNumber ==
                                                                                          contact.phoneNumber,
                                                                                    );
                                                                                  }
                                                                                },
                                                                              );
                                                                            },
                                                                    title: Text(
                                                                      contact
                                                                          .name,
                                                                      style: TextStyle(
                                                                        color:
                                                                            alreadyAdded
                                                                                ? Theme.of(
                                                                                  context,
                                                                                ).colorScheme.onPrimary.withValues(
                                                                                  alpha:
                                                                                      0.5,
                                                                                )
                                                                                : Theme.of(
                                                                                  context,
                                                                                ).colorScheme.onPrimary,
                                                                      ),
                                                                    ),
                                                                    subtitle: Row(
                                                                      children: [
                                                                        Text(
                                                                          contact
                                                                              .phoneNumber,
                                                                          style: TextStyle(
                                                                            color:
                                                                                alreadyAdded
                                                                                    ? Theme.of(
                                                                                      context,
                                                                                    ).colorScheme.onSecondary.withValues(
                                                                                      alpha:
                                                                                          0.5,
                                                                                    )
                                                                                    : Theme.of(
                                                                                      context,
                                                                                    ).colorScheme.onSecondary,
                                                                          ),
                                                                        ),
                                                                        if (alreadyAdded) ...[
                                                                          SizedBox(
                                                                            width:
                                                                                8,
                                                                          ),
                                                                          Text(
                                                                            "(Already added)",
                                                                            style: TextStyle(
                                                                              color: Theme.of(
                                                                                context,
                                                                              ).colorScheme.tertiary.withValues(
                                                                                alpha:
                                                                                    0.7,
                                                                              ),
                                                                              fontSize:
                                                                                  12,
                                                                              fontStyle:
                                                                                  FontStyle.italic,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ],
                                                                    ),
                                                                    activeColor:
                                                                        Theme.of(
                                                                          context,
                                                                        ).colorScheme.tertiary,
                                                                    checkColor:
                                                                        Theme.of(
                                                                          context,
                                                                        ).colorScheme.primary,
                                                                  );
                                                                },
                                                              ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              actions: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceEvenly,
                                                  children: [
                                                    TextButton(
                                                      onPressed:
                                                          () => Navigator.pop(
                                                            context,
                                                          ),
                                                      child: Text(
                                                        'Cancel',
                                                        style: TextStyle(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .tertiary,
                                                        ),
                                                      ),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed:
                                                          selectedContacts
                                                                  .isEmpty
                                                              ? null
                                                              : () => Navigator.pop(
                                                                context,
                                                                selectedContacts,
                                                              ),
                                                      style:
                                                          ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .tertiary,
                                                            foregroundColor:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .primary,
                                                          ),
                                                      child: Text(
                                                        'Add ${selectedContacts.length} Collaborator${selectedContacts.length == 1 ? '' : 's'}',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    );

                                    if (selectedContacts != null &&
                                        selectedContacts.isNotEmpty) {
                                      // Store original state for rollback
                                      final originalCollaborators =
                                          List<dynamic>.from(
                                            project.collaborators,
                                          );

                                      // Add all selected collaborators
                                      setState(() {
                                        for (final contact
                                            in selectedContacts) {
                                          if (!project.collaborators.contains(
                                            contact.phoneNumber,
                                          )) {
                                            project.collaborators.add(
                                              contact.phoneNumber,
                                            );
                                          }
                                        }
                                      });

                                      // Update project in database
                                      try {
                                        final updatedProject = project.copyWith(
                                          collaborators: project.collaborators,
                                        );
                                        final projectData =
                                            updatedProject.toMap();
                                        projectData['_id'] = updatedProject.id;

                                        bool success =
                                            await ProjectsAdapter.updateProject(
                                              projectData,
                                            );
                                        if (success) {
                                          widget.onUpdate(updatedProject);
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  selectedContacts.length == 1
                                                      ? 'Collaborator "${selectedContacts.first.name}" added successfully'
                                                      : '${selectedContacts.length} collaborators added successfully',
                                                ),
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        } else {
                                          // Revert the local change if database update failed
                                          setState(() {
                                            project.collaborators.clear();
                                            project.collaborators.addAll(
                                              originalCollaborators,
                                            );
                                          });
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Failed to add collaborators',
                                                ),
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        }
                                      } catch (e) {
                                        print('Error adding collaborators: $e');
                                        // Revert the local change if database update failed
                                        setState(() {
                                          project.collaborators.clear();
                                          project.collaborators.addAll(
                                            originalCollaborators,
                                          );
                                        });
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Error adding collaborators: $e',
                                              ),
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                            subtitle:
                                project.collaborators.isEmpty
                                    ? Container(
                                      margin: EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      child: Text(
                                        fetchingContacts
                                            ? ""
                                            : "No collaborators",
                                        style: TextStyle(
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onSecondary,
                                          fontSize: 14,
                                        ),
                                      ),
                                    )
                                    : Container(
                                      margin: EdgeInsets.symmetric(vertical: 8),
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children:
                                            project.collaborators.map((
                                              phoneNumber,
                                            ) {
                                              // Map over phone numbers
                                              final contact = globalContacts
                                                  .firstWhere(
                                                    (c) =>
                                                        c.phoneNumber ==
                                                        phoneNumber,
                                                    orElse:
                                                        () => Contact(
                                                          id: 0,
                                                          name: "Unknown",
                                                          organization: "",
                                                          phoneNumber:
                                                              phoneNumber,
                                                          position: "",
                                                          starred: false,
                                                        ),
                                                  );
                                              return GestureDetector(
                                                onTap:
                                                    fetchingContacts
                                                        ? null
                                                        : () {
                                                          setState(() {
                                                            openedContact =
                                                                contact;
                                                          });
                                                        },
                                                child: Chip(
                                                  backgroundColor: Theme.of(
                                                        context,
                                                      ).colorScheme.primary
                                                      .withAlpha(205),
                                                  shape: StadiumBorder(
                                                    side: BorderSide(
                                                      color:
                                                          Theme.of(context)
                                                              .colorScheme
                                                              .secondary,
                                                      width: 2,
                                                    ),
                                                  ),
                                                  label: Text(
                                                    contact.name,
                                                    style: TextStyle(
                                                      color:
                                                          Theme.of(context)
                                                              .colorScheme
                                                              .onPrimary,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  deleteIcon: Icon(
                                                    Icons.close,
                                                    color:
                                                        Theme.of(
                                                          context,
                                                        ).colorScheme.onPrimary,
                                                    size: 16,
                                                  ),
                                                  onDeleted: () async {
                                                    // Show confirmation dialog using DialogHelper
                                                    DialogHelper.showDeleteConfirmation(
                                                      context: context,
                                                      title:
                                                          'Remove Collaborator',
                                                      content:
                                                          'Remove ${contact.name} from this project?',
                                                      onDelete: () async {
                                                        // Remove collaborator from local state
                                                        setState(() {
                                                          project.collaborators
                                                              .remove(
                                                                phoneNumber,
                                                              );
                                                        });

                                                        // Update project in database
                                                        try {
                                                          final updatedProject =
                                                              project.copyWith(
                                                                collaborators:
                                                                    project
                                                                        .collaborators,
                                                              );
                                                          final projectData =
                                                              updatedProject
                                                                  .toMap();
                                                          projectData['_id'] =
                                                              updatedProject.id;

                                                          bool success =
                                                              await ProjectsAdapter.updateProject(
                                                                projectData,
                                                              );
                                                          if (success) {
                                                            widget.onUpdate(
                                                              updatedProject,
                                                            );
                                                            if (mounted) {
                                                              ScaffoldMessenger.of(
                                                                context,
                                                              ).showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                    '${contact.name} removed from project',
                                                                  ),
                                                                  duration:
                                                                      Duration(
                                                                        seconds:
                                                                            2,
                                                                      ),
                                                                ),
                                                              );
                                                            }
                                                          } else {
                                                            // Revert the local change if database update failed
                                                            setState(() {
                                                              project
                                                                  .collaborators
                                                                  .add(
                                                                    phoneNumber,
                                                                  );
                                                            });
                                                            if (mounted) {
                                                              ScaffoldMessenger.of(
                                                                context,
                                                              ).showSnackBar(
                                                                const SnackBar(
                                                                  content: Text(
                                                                    'Failed to remove collaborator',
                                                                  ),
                                                                  duration:
                                                                      Duration(
                                                                        seconds:
                                                                            2,
                                                                      ),
                                                                ),
                                                              );
                                                            }
                                                          }
                                                        } catch (e) {
                                                          print(
                                                            'Error removing collaborator: $e',
                                                          );
                                                          // Revert the local change if database update failed
                                                          setState(() {
                                                            project
                                                                .collaborators
                                                                .add(
                                                                  phoneNumber,
                                                                );
                                                          });
                                                          if (mounted) {
                                                            ScaffoldMessenger.of(
                                                              context,
                                                            ).showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                  'Error removing collaborator: $e',
                                                                ),
                                                                duration:
                                                                    Duration(
                                                                      seconds:
                                                                          2,
                                                                    ),
                                                              ),
                                                            );
                                                          }
                                                        }
                                                      },
                                                    );
                                                  },
                                                ),
                                              );
                                            }).toList(),
                                      ),
                                    ),
                          ),
                        ],
                      ),
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
