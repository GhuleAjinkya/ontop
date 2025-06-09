import 'package:flutter/material.dart';
import 'dart:ui';
import 'models/project.dart';
import 'models/to_do_item.dart';
import 'main.dart';
import 'class_contacts.dart';
import 'user_session.dart';
import 'services/projects_adapter.dart';
import 'services/contacts_adapter.dart';

class Projects extends StatefulWidget {
  const Projects({super.key});

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
      List<Map<String, dynamic>> fetchedContacts = await ContactsAdapter.getContacts();
      globalContacts = fetchedContacts.map((doc) => Contact.fromMongo(doc)).toList();
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
      setState(() {fetchingProjects = true;});
      List<Map<String, dynamic>> fetchedProjects = await ProjectsAdapter.getProjects();

      // Convert documents to Project objects
      projects = fetchedProjects.map((doc) => Project.fromMongo(doc)).toList();

      print("Successfully loaded ${projects.length} projects for user $userId");
      setState(() {fetchingProjects = false;});
    } catch (e) {
      print("Error loading projects: $e");
      projects = [];

      if (mounted) {
        setState(() {fetchingProjects = false;});
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
      filteredProjects = allProjects.where((project) {
        // Search in project title, description, and collaborator names
        final titleMatch = project.title.toLowerCase().contains(searchQuery.toLowerCase());
        final descriptionMatch = project.description.toLowerCase().contains(searchQuery.toLowerCase());
        
        // Search in collaborator names
        final collaboratorMatch = project.collaborators.any((phone) {
          final contact = globalContacts.firstWhere(
            (c) => c.phoneNumber == phone,
            orElse: () => Contact(
              id: 0,
              name: "Unknown",
              organization: "",
              phoneNumber: phone,
              position: "",
              starred: 0,
            ),
          );
          return contact.name.toLowerCase().contains(searchQuery.toLowerCase());
        });
        
        return titleMatch || descriptionMatch || collaboratorMatch;
      }).toList();
    }
    
    // Filter projects based on selected tab (Ongoing vs Completed)
    List<Project> tabFilteredProjects;
    if (selectedTab == 'Ongoing') {
      tabFilteredProjects = filteredProjects.where((p) => p.isCompleted != true).toList();
    } else {
      tabFilteredProjects = filteredProjects.where((p) => p.isCompleted == true).toList();
    }
    
    // Sort projects: for completed projects, show recently completed first
    // For ongoing projects, sort by creation date (most recent first)
    tabFilteredProjects.sort((a, b) {
      if (selectedTab == 'Completed') {
        // For completed projects, prioritize:
        // 1. Recently checked off (isCompleted true but completedAt null)
        // 2. Most recently completed (by completedAt)
        // 3. Fall back to creation date if needed
        if (a.isCompleted == true && a.completedAt == null && b.isCompleted == true && b.completedAt != null) {
          return -1; // a was just checked off, should come before b
        }
        if (a.isCompleted == true && a.completedAt != null && b.isCompleted == true && b.completedAt == null) {
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
              fetchingProjects ? 
              CircularProgressIndicator(
                color: Theme.of(context).colorScheme.tertiary,
              )
              :Icon(
                Icons.folder_outlined,
                size: 80,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              SizedBox(height: 16),
              Text(
                fetchingProjects ? "Fetching Projects...":
                selectedTab == 'Ongoing' 
                  ? (searching && searchQuery.isNotEmpty ? 'No ongoing projects found' : 'No ongoing projects')
                  : (searching && searchQuery.isNotEmpty ? 'No completed projects found' : 'No completed projects'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.tertiary,
                  fontSize: 18,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              if (!searching && selectedTab == 'Ongoing' && !fetchingProjects) ...[
                SizedBox(height: 8),
                Text(
                  'Tap the + button to add your first project',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.7),
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
        String collaboratorsText = project.collaborators.isEmpty
            ? "No collaborators"
            : "Collaborators: ${project.collaborators.map((phone) {
                final contact = globalContacts.firstWhere(
                  (c) => c.phoneNumber == phone,
                  orElse: () => Contact(
                    id: 0,
                    name: "Unknown",
                    organization: "",
                    phoneNumber: phone,
                    position: "",
                    starred: 0,
                  ),
                );
                return contact.name;
              }).take(2).join(", ")}${project.collaborators.length > 2 ? "..." : ""}";

        // Get description display text
        String descriptionText = project.description.isEmpty
            ? "No description"
            : "Description: ${project.description.length > 40 ? "${project.description.substring(0, 40)}..." : project.description}";

        // Get formatted creation date
        String creationDate = "";
        String completionDate = "";
        try {
          if (project.createdAt != null) {
            final date = project.createdAt!;
            final months = [
              '', 'January', 'February', 'March', 'April', 'May', 'June',
              'July', 'August', 'September', 'October', 'November', 'December'
            ];
            creationDate = "${date.day} ${months[date.month]}, ${date.year}";
          }
          
          // Add completion date if project is completed
          if (project.isCompleted == true && project.completedAt != null) {
            final date = project.completedAt!;
            final months = [
              '', 'January', 'February', 'March', 'April', 'May', 'June',
              'July', 'August', 'September', 'October', 'November', 'December'
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
                      color: (project.isCompleted == true) 
                        ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05)
                        : Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: (project.isCompleted == true)
                          ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1)
                          : Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
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
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: Text(
                                          project.title,
                                          style: TextStyle(
                                            color: (project.isCompleted == true) ? Colors.white60 : Colors.white,
                                            fontSize: 24,
                                            fontFamily: 'Poppins',
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          softWrap: true,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Functional checkbox for project completion status (top right)
                                      Flexible(
                                        flex: 0,
                                        child: GestureDetector(
                                          onTap: () async {
                                            // Toggle project completion status
                                            final newCompletionStatus = project.isCompleted != true;
                                            
                                            try {
                                              // Update project completion status in database
                                              final now = DateTime.now();
                                              final updatedProject = project.copyWith(
                                                isCompleted: newCompletionStatus,
                                                completedAt: newCompletionStatus ? now : null,
                                              );
                                              final projectData = updatedProject.toMap();
                                              projectData['_id'] = project.id;
                                              
                                              bool success = await ProjectsAdapter.updateProject(projectData);
                                              if (success) {
                                                // Update local state
                                                setState(() {
                                                  // Find and update the project in the main projects list
                                                  final projectIndex = projects.indexWhere((p) => p.id == project.id);
                                                  if (projectIndex != -1) {
                                                    projects[projectIndex] = project.copyWith(
                                                      isCompleted: newCompletionStatus,
                                                      completedAt: newCompletionStatus ? now : null,
                                                    );
                                                  }
                                                });
                                                
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      newCompletionStatus 
                                                        ? 'Project "${project.title}" marked as completed!' 
                                                        : 'Project "${project.title}" marked as incomplete!',
                                                    ),
                                                    duration: const Duration(seconds: 2),
                                                  ),
                                                );
                                              } else {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Failed to update project status'),
                                                    duration: Duration(seconds: 2),
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              print('Error updating project completion status: $e');
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error updating project: $e'),
                                                  duration: const Duration(seconds: 2),
                                                ),
                                              );
                                            }
                                          },
                                          child: Container(
                                            width: 26,
                                            height: 26,
                                            decoration: BoxDecoration(
                                              color: (project.isCompleted == true) 
                                                ? const Color(0xFFF2F2F2)
                                                : Colors.transparent,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: const Color(0xFFF2F2F2),
                                                width: 2,
                                              ),
                                            ),
                                            child: (project.isCompleted == true)
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
                                        color: (project.isCompleted == true) ? Colors.white.withValues(alpha: 0.4) : Colors.white70,
                                        fontSize: 12,
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                  // Completion date for completed projects
                                  if (project.isCompleted == true && completionDate.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      "Completed: $completionDate",
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.5),
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
                                  color: (project.isCompleted == true) ? Colors.white60 : Colors.white,
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
                                  color: (project.isCompleted == true) ? Colors.white60 : Colors.white,
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
                    color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: () async {
                      // Show confirmation dialog for project deletion
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.onSecondary,
                              width: 1.5,
                            ),
                          ),
                          title: Text(
                            'Delete Project?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          content: Text(
                            'Project "${project.title}" will be permanently deleted.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          actions: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  icon: Icon(
                                    Icons.close,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    size: 30,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  icon: Icon(
                                    Icons.check,
                                    color: Theme.of(context).colorScheme.error,
                                    size: 30,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        try {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Please wait. Updating Projects...',
                              ),
                              duration: Duration(seconds: 1),
                              showCloseIcon: true,
                            ),
                          );
                          // Delete project from database
                          bool success = await ProjectsAdapter.deleteProject(project.id!);
                          if (success) {
                            // Remove from local list
                            setState(() {
                              projects.removeWhere((p) => p.id == project.id);
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Project "${project.title}" deleted successfully'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to delete project'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          print('Error deleting project: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error deleting project: $e'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      }
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
          color: isSelected 
            ? Colors.grey[700]
            : Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected
                ? Colors.grey[700]!
                : Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.3), // Light purple
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected 
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
              openedProject = updatedProject;
            }
          });
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
                          child: Text(
                            'Projects',
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
                                    labelText: 'Search projects',
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
                      Container(
                        margin: EdgeInsets.only(right: 20),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                !searching
                                    ? Icons.search
                                    : Icons.close,
                                color:
                                    Theme.of(context).colorScheme.onPrimary,
                                size: !searching ? 30 : 25,
                              ),
                              onPressed: () {
                                setState(() {
                                  searching = !searching;
                                  searchController.clear();
                                  searchQuery = '';
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
                                    addingProject = true;
                                  });
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.more_vert,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                  size: 28,
                                ),
                                onPressed: () {
                                  // TODO: Implement more options menu
                                  setState(() {});
                                },
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
                              content: Text('Please log in to create projects'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Please wait. Updating Projects...',
                            ),
                            duration: Duration(seconds: 1),
                            showCloseIcon: true,
                          ),
                        );
                        // Create project data
                        final projectData = {
                          'title': projectTitle.text.trim(),
                          'description': '',
                          'collaborators': [], // Empty array of Contact ObjectIds
                          'project_tasks': [],
                          'type': 'project',
                          'created_at': DateTime.now().toIso8601String(),
                        };

                        setState(() {
                          addingProject = false;
                        });
                        projectTitle.clear();

                        // Store messenger reference before async operation
                        final messenger = ScaffoldMessenger.of(context);

                        // Insert using our adapter (Node.js API first, then MongoDB fallback)
                        bool success = await ProjectsAdapter.addProject(
                          projectData,
                        );

                        if (success) {
                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Project created successfully!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                          print("Project successfully added to MongoDB!");
                          await loadProjects(); // Reload projects
                        } else {
                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Failed to create project'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                          print("Failed to add project to MongoDB");
                        }
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
      setState((){fetchingContacts = true;});
      // Use ContactsAdapter instead of direct MongoDB access
      List<Map<String, dynamic>> fetchedContacts =
          await ContactsAdapter.getContacts();
      globalContacts =
          fetchedContacts.map((doc) => Contact.fromMongo(doc)).toList();
      print(
        "Successfully loaded ${globalContacts.length} contacts for project collaborators",
      );
      setState(() {fetchingContacts = false;});
    } catch (e) {
      if (mounted) {
        setState(() {fetchingContacts = false;});
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
              (c) => c.id.toString() == updatedContact.id.toString()
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
      body: SingleChildScrollView(
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
                decoration: standardTile(20),
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
                                color: Theme.of(context).colorScheme.onPrimary,
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
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Please wait. Updating Projects...',
                                            ),
                                            duration: Duration(seconds: 1),
                                            showCloseIcon: true,
                                          ),
                                        );
                                        final updatedDescription =
                                            descriptionController.text.trim();
                                        final updatedProject = project.copyWith(
                                          description: updatedDescription,
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
                                                  'Failed to update description',
                                                ),
                                                duration: Duration(seconds: 2),
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
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                                onPressed: () {
                                  setState(() {
                                    editingDescription = true;
                                  });
                                },
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
                              color: Theme.of(context).colorScheme.onSecondary,
                            ),
                            border:
                                editingDescription
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
                                editingDescription
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
                                editingDescription
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
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.add,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                              onPressed: () {
                                setState(() {
                                  openCompletedTasks = false;
                                  editingToDo = true;
                                });
                              },
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
                                          border: const UnderlineInputBorder(),
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
                                                ? "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}"
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
                                            final picked = await showDatePicker(
                                              context: context,
                                              initialDate: selectedDate ?? now,
                                              firstDate: now,
                                              lastDate: DateTime(now.year + 5),
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
                                                ? "${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}"
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
                                            final picked = await showTimePicker(
                                              context: context,
                                              initialTime:
                                                  selectedTime ??
                                                  TimeOfDay.now(),
                                              initialEntryMode:
                                                  TimePickerEntryMode.dial,
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
                                              alignment: Alignment.centerLeft,
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
                                              alignment: Alignment.centerRight,
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
                                                        const SnackBar(
                                                          content: Text(
                                                            'Task added successfully!',
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
                                                          duration: Duration(
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
                            if (project.projectTasks.isEmpty)
                              Container(
                                margin: EdgeInsets.symmetric(vertical: 10),
                                child: Text(
                                  "No tasks yet.",
                                  style: TextStyle(
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              )
                            else
                              ...project.projectTasks.map<Widget>((item) {
                                return Row(
                                  children: [
                                    Checkbox(
                                      value: completedTasks.contains(item.id),
                                      onChanged: (bool? changed) async {
                                        setState(() {
                                          if (!completedTasks.contains(
                                            item.id,
                                          )) {
                                            completedTasks.add(item.id);
                                          } else {
                                            completedTasks.remove(item.id);
                                          }
                                        });

                                        // Update project in database with completed tasks
                                        try {
                                          final updatedProject = project
                                              .copyWith(
                                                projectTasks:
                                                    project.projectTasks,
                                              );
                                          final projectData =
                                              updatedProject.toMap();
                                          projectData['_id'] =
                                              updatedProject.id;
                                          projectData['completed_tasks'] =
                                              completedTasks; // Add completed tasks tracking

                                          bool success =
                                              await ProjectsAdapter.updateProject(
                                                projectData,
                                              );
                                          if (!success) {
                                            // Revert the local change if database update failed
                                            setState(() {
                                              if (completedTasks.contains(
                                                item.id,
                                              )) {
                                                completedTasks.remove(item.id);
                                              } else {
                                                completedTasks.add(item.id);
                                              }
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
                                            if (completedTasks.contains(
                                              item.id,
                                            )) {
                                              completedTasks.remove(item.id);
                                            } else {
                                              completedTasks.add(item.id);
                                            }
                                          });
                                        }
                                      },
                                      activeColor:
                                          Theme.of(
                                            context,
                                          ).colorScheme.tertiary,
                                      checkColor:
                                          Theme.of(context).colorScheme.primary,
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
                                        // Show confirmation dialog
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder:
                                              (context) => AlertDialog(
                                                backgroundColor:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  side: BorderSide(
                                                    color:
                                                        Theme.of(context)
                                                            .colorScheme
                                                            .onSecondary,
                                                    width: 1.5,
                                                  ),
                                                ),
                                                title: Text(
                                                  'Delete Task?',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        Theme.of(
                                                          context,
                                                        ).colorScheme.onPrimary,
                                                  ),
                                                ),
                                                content: Text(
                                                  'This task will be permanently deleted.',
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
                                                        MainAxisAlignment
                                                            .spaceEvenly,
                                                    children: [
                                                      IconButton(
                                                        onPressed: () => Navigator.pop(context,false),
                                                        icon: Icon(
                                                          Icons.close,
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onPrimary,
                                                          size: 30,
                                                        ),
                                                      ),
                                                      IconButton(
                                                        onPressed:
                                                            () => Navigator.pop(
                                                              context,
                                                              true,
                                                            ),
                                                        icon: Icon(
                                                          Icons.check,
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .error,
                                                          size: 30,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                        );

                                        if (confirmed == true) {
                                          
                                          // Store original state for rollback
                                          final originalTasks =
                                              List<ToDoItem>.from(
                                                project.projectTasks,
                                              );
                                          final originalCompletedTasks =
                                              List<String>.from(completedTasks);

                                          // Remove task from local state
                                          setState(() {
                                            project.projectTasks.removeWhere(
                                              (task) => task.id == item.id,
                                            );
                                            completedTasks.remove(
                                              item.id,
                                            ); // Also remove from completed tasks if present
                                          });

                                          // Update project in database
                                          try {
                                            
                                            final updatedProject = project
                                                .copyWith(
                                                  projectTasks:
                                                      project.projectTasks,
                                                );
                                            final projectData =
                                                updatedProject.toMap();
                                            projectData['_id'] =
                                                updatedProject.id;
                                            projectData['completed_tasks'] =
                                                completedTasks;

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
                                                project.projectTasks.clear();
                                                project.projectTasks.addAll(
                                                  originalTasks,
                                                );
                                                completedTasks.clear();
                                                completedTasks.addAll(
                                                  originalCompletedTasks,
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
                                              project.projectTasks.clear();
                                              project.projectTasks.addAll(
                                                originalTasks,
                                              );
                                              completedTasks.clear();
                                              completedTasks.addAll(
                                                originalCompletedTasks,
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
                                        }
                                      },
                                    ),
                                  ],
                                );
                              }),
                          ],
                        ),
                      ),
                      divLine(),
                      ListTile(
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              fetchingContacts ? 
                              "Fetching Collaborators..."
                              : "Collaborators",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.add,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                              onPressed: () async {
                                final selected = await showDialog<Contact>(
                                  context: context,
                                  builder: (context) {
                                    String search = '';
                                    List<Contact> filtered = globalContacts;
                                    TextEditingController searchController =
                                        TextEditingController();
                                    bool fetchingContacts = false;
                                    int loop = 0;
                                    return StatefulBuilder(
                                      builder: (context, setDialogState) {
                                        // Filter contacts by search query with improved ordering
                                        if (globalContacts.isEmpty && contactsFetched == false) {
                                          loop += 1;
                                          print("loops = $loop\n");
                                          setDialogState((){
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
                                          filtered = globalContacts.where((c) =>
                                            c.name.toLowerCase().contains(search.toLowerCase()) ||
                                            c.phoneNumber.toLowerCase().contains(search.toLowerCase())
                                          ).toList();
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

                                            if (aStartsWith && !bStartsWith) {
                                              return -1;
                                            }
                                            if (!aStartsWith && bStartsWith) {
                                              return 1;
                                            }

                                            // If both start with query, prioritize name matches over phone matches
                                            if (aStartsWith && bStartsWith) {
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
                                          backgroundColor: Theme.of(context).colorScheme.primary,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            side: BorderSide(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onPrimary,
                                              width: 1,
                                            ),
                                          ),
                                          title: Text(
                                            'Add Collaborator',
                                            style: TextStyle(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          content: SizedBox(
                                            width: 200,
                                            height: 200,
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                TextField(
                                                  controller: searchController,
                                                  maxLines: 1,
                                                  style: TextStyle(
                                                    color:
                                                        Theme.of(
                                                          context,
                                                        ).colorScheme.onPrimary,
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
                                                      color: Theme.of(context)
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
                                                          borderSide:
                                                              BorderSide(
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
                                                    focusedBorder:
                                                        OutlineInputBorder(
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
                                                Expanded(
                                                  child:
                                                    fetchingContacts ? 
                                                      Container(
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
                                                                        )
                                                                        .colorScheme
                                                                        .tertiary,
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
                                                                        )
                                                                        .colorScheme
                                                                        .tertiary,
                                                              ),
                                                            ),
                                                          )
                                                          : ListView.builder(
                                                            itemCount:
                                                                filtered.length,
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
                                                                        contact
                                                                            .phoneNumber,
                                                                  );
                                                              return ListTile(
                                                                title: Text(
                                                                  contact.name,
                                                                  style: TextStyle(
                                                                    color:
                                                                        Theme.of(
                                                                          context,
                                                                        ).colorScheme.onPrimary,
                                                                  ),
                                                                ),
                                                                subtitle: Text(
                                                                  contact
                                                                      .phoneNumber,
                                                                  style: TextStyle(
                                                                    color:
                                                                        Theme.of(
                                                                          context,
                                                                        ).colorScheme.onSecondary,
                                                                  ),
                                                                ),
                                                                trailing:
                                                                    alreadyAdded
                                                                        ? Icon(
                                                                          Icons
                                                                              .check,
                                                                          color:
                                                                              Theme.of(
                                                                                context,
                                                                              ).colorScheme.secondary,
                                                                        )
                                                                        : null,
                                                                enabled:
                                                                    !alreadyAdded,
                                                                onTap:
                                                                    alreadyAdded
                                                                        ? null
                                                                        : () {
                                                                          Navigator.of(
                                                                            context,
                                                                          ).pop(
                                                                            contact,
                                                                          );
                                                                        },
                                                              );
                                                            },
                                                          ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed:
                                                  () => Navigator.pop(context),
                                              child: Text(
                                                'Cancel',
                                                style: TextStyle(
                                                  color:
                                                      Theme.of(
                                                        context,
                                                      ).colorScheme.tertiary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                );
                                if (selected != null &&
                                    !project.collaborators.contains(
                                      selected.phoneNumber,
                                    )) {
                                  // Store original state for rollback
                                  final originalCollaborators =
                                      List<dynamic>.from(project.collaborators);

                                  setState(() {
                                    project.collaborators.add(
                                      selected.phoneNumber,
                                    ); // Add phone number string, not Contact
                                  });

                                  // Update project in database
                                  try {
                                    final updatedProject = project.copyWith(
                                      collaborators: project.collaborators,
                                    );
                                    final projectData = updatedProject.toMap();
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
                                              'Collaborator "${selected.name}" added successfully',
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
                                              'Failed to add collaborator',
                                            ),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    print('Error adding collaborator: $e');
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
                                            'Error adding collaborator: $e',
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
                                  margin: EdgeInsets.symmetric(vertical: 10),
                                  child: Text(
                                    fetchingContacts ? "" : "No collaborators",
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
                                                      phoneNumber: phoneNumber,
                                                      position: "",
                                                      starred: 0,
                                                    ),
                                              );
                                          return GestureDetector(
                                            onTap: fetchingContacts ?
                                            null :
                                            () {
                                              setState(() {
                                                openedContact = contact;
                                              });
                                            },
                                            child: Chip(
                                              backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(205),
                                              shape: StadiumBorder(
                                                side: BorderSide(
                                                  color: Theme.of(context).colorScheme.secondary,
                                                  width: 2,
                                                ),
                                              ),
                                              label: Text(
                                                contact.name,
                                                style: TextStyle(
                                                  color:
                                                      Theme.of(
                                                        context,
                                                      ).colorScheme.onPrimary,
                                                  fontWeight: FontWeight.w500,
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
                                                // Show confirmation dialog
                                                final confirmed = await showDialog<
                                                  bool
                                                >(
                                                  context: context,
                                                  builder:
                                                      (
                                                        context,
                                                      ) => AlertDialog(
                                                        backgroundColor:
                                                            Theme.of(context)
                                                                .colorScheme
                                                                .primary,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                16,
                                                              ),
                                                          side: BorderSide(
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .onPrimary,
                                                            width: 1,
                                                          ),
                                                        ),
                                                        title: Text(
                                                          'Remove Collaborator',
                                                          style: TextStyle(
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .onPrimary,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600,
                                                          ),
                                                        ),
                                                        content: Text(
                                                          'Remove ${contact.name} from this project?',
                                                          style: TextStyle(
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .onPrimary,
                                                          ),
                                                        ),
                                                        actions: [
                                                          Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .spaceEvenly,
                                                            children: [
                                                              IconButton(
                                                                onPressed:
                                                                    () => Navigator.pop(
                                                                      context,
                                                                      false,
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
                                                                onPressed:
                                                                    () => Navigator.pop(
                                                                      context,
                                                                      true,
                                                                    ),
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
                                            
                                                if (confirmed == true) {
                                                  // Remove collaborator from local state
                                                  setState(() {
                                                    project.collaborators
                                                        .remove(phoneNumber);
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
                                                                  seconds: 2,
                                                                ),
                                                          ),
                                                        );
                                                      }
                                                    } else {
                                                      // Revert the local change if database update failed
                                                      setState(() {
                                                        project.collaborators
                                                            .add(phoneNumber);
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
                                                                  seconds: 2,
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
                                                      project.collaborators
                                                          .add(phoneNumber);
                                                    });
                                                    if (mounted) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            'Error removing collaborator: $e',
                                                          ),
                                                          duration: Duration(
                                                            seconds: 2,
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  }
                                                }
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
    );
  }
}
