import 'package:flutter/material.dart';
import 'dart:ui'; // For ImageFilter
import '../home/main.dart';
import 'tasks_adapter.dart';
import '../shared/optimistic_updates.dart';
import 'project_tasks_sync.dart';
import '../shared/date_formatter.dart';

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

class Tasks extends StatefulWidget {
  const Tasks({super.key});

  @override
  State<Tasks> createState() => _TasksState();
}

class _TasksState extends State<Tasks> {
  // Data structures - now backed by MongoDB
  Map<String, List<ToDoItem>> sections = {};
  Map<String, List<ToDoItem>> completedSections = {};
  List<TaskSection> taskSections = [];

  // UI state
  String? addingItemInSection;
  bool addingSection = false;
  List<String> collapsedSections = [];
  bool openCompleted = false;
  Map<String, Set<String>> selectedTaskIDs =
      {}; // Changed from int to String for MongoDB
  bool allSelectedFromSection = false;
  bool searching = false;
  String searchQuery = '';

  // Controllers
  final TextEditingController textController = TextEditingController();
  final TextEditingController sectionName = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  // Date/time selection
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  String? selectedSection;

  // Loading state
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasksFromDatabase();
  }

  /// Load all tasks and sections from MongoDB
  Future<void> _loadTasksFromDatabase() async {
    setState(() {
      isLoading = true;
    });
    try {
      // Load sections and tasks
      taskSections = await TasksAdapter.loadSections();
      final allTasks = await TasksAdapter.loadTasks();

      // Sort sections: User sections first (by last interaction), then project sections (by last interaction)
      taskSections.sort((a, b) {
        // First separate by type
        if (a.type != b.type) {
          return a.type == SectionType.userCreated ? -1 : 1;
        }

        // Within same type, sort by last interaction (most recent first)
        final aTime =
            a.lastInteracted ?? DateTime(2000); // Default old date for null
        final bTime = b.lastInteracted ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });

      // Organize tasks by section
      sections.clear();
      completedSections.clear();

      for (final section in taskSections) {
        final sectionTasks =
            allTasks.where((task) => task.sectionId == section.id).toList();
        final todoTasks =
            sectionTasks.where((task) => !task.isCompleted).toList();
        final completedTasks =
            sectionTasks.where((task) => task.isCompleted).toList();

        // Sort tasks: for ongoing tasks, sort by deadline (earliest first)
        // For completed tasks, show recently completed first (using completedAt timestamp)
        todoTasks.sort((a, b) {
          if (a.deadlineDate.isBefore(b.deadlineDate)) return -1;
          if (a.deadlineDate.isAfter(b.deadlineDate)) return 1;
          return 0;
        });

        // For completed tasks, sort by completion time (most recently completed first)
        completedTasks.sort((a, b) {
          // Prioritize tasks with completedAt timestamp
          if (a.completedAt != null && b.completedAt != null) {
            return b.completedAt!.compareTo(a.completedAt!);
          }
          // If one has completedAt and other doesn't, prioritize the one with timestamp
          if (a.completedAt != null && b.completedAt == null) return -1;
          if (a.completedAt == null && b.completedAt != null) return 1;
          // Fall back to deadline date for tasks without completedAt (legacy tasks)
          if (a.deadlineDate.isBefore(b.deadlineDate)) return 1;
          if (a.deadlineDate.isAfter(b.deadlineDate)) return -1;
          return 0;
        });

        // Always add sections to the maps, even if empty, so they appear in the UI
        sections[section.name] = todoTasks;
        if (completedTasks.isNotEmpty) {
          completedSections[section.name] = completedTasks;
        }
      }
    } catch (e) {
      print('Error loading tasks from database: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load tasks: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  bool areSelectedTasksEmpty() {
    return selectedTaskIDs.keys.every(
      (sectionKey) => selectedTaskIDs[sectionKey]?.isEmpty ?? true,
    );
  }

  bool isSameDay(DateTime day1, DateTime day2) {
    return day1.year == day2.year &&
        day1.month == day2.month &&
        day1.day == day2.day;
  }

  void clearItem() {
    setState(() {
      addingItemInSection = null;
      addingSection = false;
    });
  }

  void _showSectionDialog() {
    final sectionController = TextEditingController();

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
              'Add New Section',
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
                      controller: sectionController,
                      label: 'Section Name',
                      hint: 'Enter section name',
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
                onPressed: () => _saveSection(sectionController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: Text('Add', style: TextStyle(fontFamily: 'Poppins')),
              ),
            ],
          ),
    );
  }

  void _showTaskDialog(String sectionKey) {
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
                  content: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.85,
                    child: SingleChildScrollView(
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
                                      builder: DateFormatter.datePickerBuilder,
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
                                          Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                      fontSize: 12,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  onPressed: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime:
                                          selectedTime ?? TimeOfDay.now(),
                                      initialEntryMode:
                                          TimePickerEntryMode.dial,
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
                            sectionKey: sectionKey,
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

  void _saveSection(String sectionName) async {
    if (sectionName.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Section name is required')));
      return;
    }

    // Check if section already exists
    if (taskSections.any((section) => section.name == sectionName.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Section "${sectionName.trim()}" already exists'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    Navigator.pop(context);

    final tempSection = TaskSection(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      name: sectionName.trim(),
      isCompleted: false,
      type: SectionType.userCreated,
      lastInteracted: DateTime.now(),
    );
    
    OptimisticUpdates.perform(
      updateLocalState: () {
        setState(() {
          taskSections.add(tempSection);
          sections = {
            tempSection.name: [],
            ...sections,
          };
        });
      }, 
      databaseOperation: () => TasksAdapter.createSection(tempSection.name), 
      revertLocalState: () {
        setState(() {
          taskSections.removeWhere((section) => section.id == tempSection.id);
          sections.remove(tempSection.name);
        }); 
      },
      onSuccess: () async {
        final allSections = await TasksAdapter.loadSections();
        final realSection = allSections.firstWhere(
          (s) => s.name == tempSection.name,
          orElse: () => tempSection, // fallback, should not happen
        );

        setState(() {
          // Replace the temp section in taskSections with the real one
          final idx = taskSections.indexWhere((s) => s.id == tempSection.id);
          if (idx != -1) {
            taskSections[idx] = realSection;
            // If you ever use section IDs as keys in maps, update those keys here as well
          }
        });
      },
      context: context,
      showSuccessMessage: "Section ${tempSection.name} added",
      showErrorMessage: "Couldn't add new section",
    );
    
  }

  void _saveTask({
    required String sectionKey,
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

    try {
      final deadline = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );

      // Find the section ID
      final section = taskSections.firstWhere(
        (s) => s.name == sectionKey,
        orElse: () => throw Exception('Section not found'),
      );

      // Check if this is a project section to set projectId
      final isProjectSection = section.type == SectionType.projectLinked;

      // Implement optimistic task creation
      final tempTask = ToDoItem(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        sectionId: section.id,
        projectId: isProjectSection ? section.projectId : null,
        text: taskText.trim(),
        deadlineDate: deadline,
        isCompleted: false,
        completedAt: null,
      );

      // Ensure the section exists in our local state
      if (sections[sectionKey] == null) {
        sections[sectionKey] = [];
      }
      
      

      OptimisticUpdates.perform(
        updateLocalState: () {
          setState(() {
            sections[sectionKey]!.add(tempTask);
            sections[sectionKey]!.sort((a,b) {
              if (a.deadlineDate.isBefore(b.deadlineDate)) return -1;
              if (a.deadlineDate.isAfter(b.deadlineDate)) return 1;
              return 0;
            });
          });
        }, 
        databaseOperation: () => TasksAdapter.createTask(section.id, taskText.trim(), deadline),
        revertLocalState: () => sections[sectionKey]!.remove(tempTask),
        onSuccess: () async {
          final realTasks = await TasksAdapter.getTasksForSection(section.id);
          setState(() {
            // Replace the section's task list with the up-to-date list from DB
            sections[sectionKey] = realTasks.where((t) => !t.isCompleted).toList();
            completedSections[sectionKey] = realTasks.where((t) => t.isCompleted).toList();
          });
          if (isProjectSection && section.projectId != null) {
            ProjectTasksSync.syncTaskToProject(
              projectId: section.projectId!, 
              taskText: taskText.trim(), 
              taskDeadline: deadline
            );
          }
          
        },
        context: context,
        showErrorMessage: "Couldn't create task.",
      );

    } catch (e) {
      print('Error creating task: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create task: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Widget buildToDoItemTiles(
    BuildContext context,
    String sectionTitle,
    List<ToDoItem> toDoItems,
    bool completed,
  ) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      shrinkWrap: true,
      itemCount: toDoItems.length,
      itemBuilder: (context, index) {
        final toDoItem = toDoItems[index];
        bool pastDeadline = toDoItem.deadlineDate.isBefore(DateTime.now());
        if (!selectedTaskIDs.containsKey(sectionTitle)) {
          selectedTaskIDs[sectionTitle] = {};
        }
        final isSelected = (selectedTaskIDs[sectionTitle] ?? {}).contains(
          toDoItem.id,
        );
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
          child: Container(
            decoration: standardTile(10, isSelected: isSelected),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: ListTile(
              minLeadingWidth: 0,
              selected: false,
              dense: true,
              leading: Container(
                margin: EdgeInsets.all(0),
                child: IconButton(
                  icon: Icon(
                    completed
                        ? Icons.check_circle_outline
                        : Icons.circle_outlined,
                    color:
                        completed
                            ? Theme.of(context).colorScheme.tertiary
                            : Theme.of(context).colorScheme.onPrimary,
                  ),
                  onPressed: () async {
                    // Store original section for rollback
                    String? originalSectionName;
                    List<ToDoItem>? originalSourceList;
                    int originalIndex = -1;

                    // Find the task in current sections
                    for (final entry in sections.entries) {
                      final index = entry.value.indexWhere(
                        (t) => t.id == toDoItem.id,
                      );
                      if (index != -1) {
                        originalSectionName = entry.key;
                        originalSourceList = List.from(entry.value);
                        originalIndex = index;
                        break;
                      }
                    }

                    if (originalSectionName == null) {
                      for (final entry in completedSections.entries) {
                        final index = entry.value.indexWhere(
                          (t) => t.id == toDoItem.id,
                        );
                        if (index != -1) {
                          originalSectionName = entry.key;
                          originalSourceList = List.from(entry.value);
                          originalIndex = index;
                          break;
                        }
                      }
                    }

                    if (originalSectionName == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Task not found'),
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                      );
                      return;
                    }

                    final sectionName = originalSectionName;

                    // Step 1: Update local state immediately
                    setState(() {
                      if (completed) {
                        // Moving from completed to todo
                        completedSections[sectionName]?.removeAt(originalIndex);
                        if (sections[sectionName] == null) {
                          sections[sectionName] = [];
                        }
                        final updatedTask = toDoItem.copyWith(
                          isCompleted: false,
                          completedAt: null,
                        );
                        sections[sectionName]!.add(updatedTask);

                        // Sort by deadline
                        sections[sectionName]!.sort((a, b) {
                          if (a.deadlineDate.isBefore(b.deadlineDate)) {
                            return -1;
                          }
                          if (a.deadlineDate.isAfter(b.deadlineDate)) return 1;
                          return 0;
                        });
                      } else {
                        // Moving from todo to completed
                        sections[sectionName]?.removeAt(originalIndex);
                        if (completedSections[sectionName] == null) {
                          completedSections[sectionName] = [];
                        }
                        final updatedTask = toDoItem.copyWith(
                          isCompleted: true,
                          completedAt: DateTime.now(),
                        );
                        completedSections[sectionName]!.insert(0, updatedTask);
                      }
                    }); // Step 2: Perform database operation
                    try {
                      await TasksAdapter.updateTaskCompletion(
                        toDoItem.id,
                        !completed,
                      );

                      // Step 2.5: Sync completion back to project if this is a project task
                      if (toDoItem.projectId != null &&
                          toDoItem.projectId!.isNotEmpty) {
                        await ProjectTasksSync.syncTaskCompletionToProject(
                          taskId: toDoItem.id,
                          projectId: toDoItem.projectId!,
                          isCompleted: !completed,
                        );
                      }

                      // Step 3: Show success message (optional)
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              completed
                                  ? 'Task marked as incomplete'
                                  : 'Task marked as complete',
                            ),
                            backgroundColor:
                                Theme.of(context).colorScheme.tertiary,
                            duration: Duration(milliseconds: 1500),
                          ),
                        );
                      }
                    } catch (e) {
                      print('Error updating task completion: $e');

                      // Step 4: Revert local state
                      setState(() {
                        if (completed) {
                          // Revert: put task back in completed list
                          sections[sectionName]?.removeWhere(
                            (t) => t.id == toDoItem.id,
                          );
                          if (originalSourceList != null) {
                            completedSections[sectionName] = originalSourceList;
                          }
                        } else {
                          // Revert: put task back in todo list
                          completedSections[sectionName]?.removeWhere(
                            (t) => t.id == toDoItem.id,
                          );
                          if (originalSourceList != null) {
                            sections[sectionName] = originalSourceList;
                          }
                        }
                      });

                      // Step 5: Show error message
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to update task: $e'),
                            backgroundColor:
                                Theme.of(context).colorScheme.error,
                          ),
                        );
                      }

                      // Reload data for consistency
                      await _loadTasksFromDatabase();
                    }
                  },
                ),
              ),
              title: Text(
                toDoItem.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              subtitle: Text(
                !completed
                    ? isSameDay(toDoItem.deadlineDate, DateTime.now())
                        ? "Due Today, ${DateFormatter.formatTime(toDoItem.deadlineDate)}"
                        : "Due ${DateFormatter.formatDate(toDoItem.deadlineDate)}"
                    : toDoItem.completedAt != null
                    ? DateFormatter.formatCompletedDate(toDoItem.completedAt!)
                    : DateFormatter.formatCompletedDate(toDoItem.deadlineDate),
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
              trailing: Icon(
                !completed
                    ? pastDeadline
                        ? Icons.watch_later_outlined
                        : null
                    : null,
                color: Theme.of(context).colorScheme.error,
              ),
              onLongPress: () {
                setState(() {
                  if (!isSelected) {
                    if (!selectedTaskIDs.containsKey(sectionTitle)) {
                      selectedTaskIDs[sectionTitle] = {};
                    }
                    selectedTaskIDs[sectionTitle]!.add(toDoItem.id);
                  }
                  searching = false;
                });
              },
              onTap: () {
                setState(() {
                  if (!areSelectedTasksEmpty()) {
                    if (isSelected) {
                      selectedTaskIDs[sectionTitle]!.remove(toDoItem.id);
                    } else {
                      selectedTaskIDs[sectionTitle]!.add(toDoItem.id);
                    }
                  }
                });
              },
            ),
          ),
        );
      },
    );
  }

  Widget buildSectionWidget(int i, bool completed) {
    String sectionKey =
        (completed ? completedSections : sections).keys.toList()[i];
    bool collapseSection = collapsedSections.contains(sectionKey);
    bool empty =
        completed
            ? completedSections[sectionKey]?.isEmpty ?? true
            : sections[sectionKey]?.isEmpty ?? true;

    // Find the section to check if it's project-linked
    final section = taskSections.firstWhere(
      (s) => s.name == sectionKey,
      orElse: () => TaskSection(id: '', name: sectionKey, isCompleted: false),
    );
    final isProjectSection = section.type == SectionType.projectLinked;

    return Column(
      children: [
        Container(
          margin: EdgeInsets.symmetric(horizontal: 40, vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              InkWell(
                onTap: () {
                  if (!completed) {
                    _showTaskDialog(sectionKey);
                  }
                },
                onLongPress: () {
                  showDialog(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.onSecondary,
                              width: 1.5,
                            ),
                          ),
                          title: Text(
                            'Delete Section "$sectionKey"?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          content: Text(
                            'Selected section will be permanently deleted.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          actions: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.tertiary,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    // Find the section to delete
                                    final sectionToDelete = taskSections
                                        .firstWhere(
                                          (section) =>
                                              section.name == sectionKey,
                                          orElse:
                                              () =>
                                                  throw Exception(
                                                    'Section not found',
                                                  ),
                                        );

                                    // Store original state for rollback
                                    final originalTaskSections =
                                        List<TaskSection>.from(taskSections);
                                    final originalSections =
                                        Map<String, List<ToDoItem>>.from(
                                          sections,
                                        );
                                    final originalCompletedSections =
                                        Map<String, List<ToDoItem>>.from(
                                          completedSections,
                                        );

                                    // Step 1: Update local state immediately (remove section)
                                    setState(() {
                                      taskSections.removeWhere(
                                        (s) => s.id == sectionToDelete.id,
                                      );
                                      sections.remove(sectionKey);
                                      completedSections.remove(sectionKey);
                                    });

                                    if (mounted) {
                                      Navigator.pop(context);
                                    }

                                    // Step 2: Perform database operation
                                    try {
                                      final success =
                                          await TasksAdapter.deleteSection(
                                            sectionToDelete.id,
                                          );

                                      if (!success) {
                                        throw Exception(
                                          'Database operation failed',
                                        );
                                      }

                                      // Step 3: Show success message
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Section "$sectionKey" deleted successfully',
                                            ),
                                            backgroundColor:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.tertiary,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      // Step 4: Revert local state if database operation failed
                                      setState(() {
                                        taskSections.clear();
                                        taskSections.addAll(
                                          originalTaskSections,
                                        );
                                        sections.clear();
                                        sections.addAll(originalSections);
                                        completedSections.clear();
                                        completedSections.addAll(
                                          originalCompletedSections,
                                        );
                                      });

                                      // Step 5: Show error message
                                      print('Error deleting section: $e');
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Failed to delete section: $e',
                                            ),
                                            backgroundColor:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.error,
                                          ),
                                        );
                                      } // Reload data to ensure consistency
                                      _loadTasksFromDatabase();
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text(
                                    'Delete',
                                    style: TextStyle(fontFamily: 'Poppins'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                  );
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    !completed
                        ? Icon(
                          Icons.add,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 20,
                        )
                        : Container(),
                    if (isProjectSection) ...[
                      Icon(
                        Icons.folder_outlined,
                        color: Theme.of(context).colorScheme.tertiary,
                        size: 16,
                      ),
                      SizedBox(width: 4),
                    ],
                    Text(
                      sectionKey,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontStyle:
                            isProjectSection
                                ? FontStyle.italic
                                : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(left: 10),
                  height: 1,
                  decoration: BoxDecoration(
                    border: Border.all(
                      width: 2,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
              IconButton(
                alignment: Alignment.topCenter,
                onPressed: () {
                  if (empty) {
                    showDialog(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color:
                                    Theme.of(context).colorScheme.onSecondary,
                                width: 1.5,
                              ),
                            ),
                            title: Text(
                              'Delete Section "$sectionKey"?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                            content: Text(
                              'Selected section will be permanently deleted.',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.tertiary,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  // Find the section to delete
                                  final sectionToDelete = taskSections
                                      .firstWhere(
                                        (section) => section.name == sectionKey,
                                        orElse:
                                            () =>
                                                throw Exception(
                                                  'Section not found',
                                                ),
                                      );

                                  // Store original state for rollback
                                  final originalTaskSections =
                                      List<TaskSection>.from(taskSections);
                                  final originalSections =
                                      Map<String, List<ToDoItem>>.from(
                                        sections,
                                      );
                                  final originalCompletedSections =
                                      Map<String, List<ToDoItem>>.from(
                                        completedSections,
                                      );

                                  // Step 1: Update local state immediately (remove section)
                                  setState(() {
                                    taskSections.removeWhere(
                                      (s) => s.id == sectionToDelete.id,
                                    );
                                    sections.remove(sectionKey);
                                    completedSections.remove(sectionKey);
                                  });

                                  if (mounted) {
                                    Navigator.pop(context);
                                  }

                                  // Step 2: Perform database operation
                                  try {
                                    final success =
                                        await TasksAdapter.deleteSection(
                                          sectionToDelete.id,
                                        );

                                    if (!success) {
                                      throw Exception(
                                        'Database operation failed',
                                      );
                                    }

                                    // Step 3: Show success message
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Section "$sectionKey" deleted successfully',
                                          ),
                                          backgroundColor:
                                              Theme.of(
                                                context,
                                              ).colorScheme.tertiary,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    // Step 4: Revert local state if database operation failed
                                    setState(() {
                                      taskSections.clear();
                                      taskSections.addAll(originalTaskSections);
                                      sections.clear();
                                      sections.addAll(originalSections);
                                      completedSections.clear();
                                      completedSections.addAll(
                                        originalCompletedSections,
                                      );
                                    });

                                    // Step 5: Show error message
                                    print('Error deleting section: $e');
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to delete section: $e',
                                          ),
                                          backgroundColor:
                                              Theme.of(
                                                context,
                                              ).colorScheme.error,
                                        ),
                                      );
                                    } // Reload data to ensure consistency
                                    _loadTasksFromDatabase();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(
                                  'Delete',
                                  style: TextStyle(fontFamily: 'Poppins'),
                                ),
                              ),
                            ],
                          ),
                    );
                  } else {
                    setState(() {
                      if (collapseSection) {
                        collapsedSections.remove(sectionKey);
                      } else {
                        collapsedSections.add(sectionKey);
                      }
                    });
                  }
                },
                onLongPress: () {
                  showDialog(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.onSecondary,
                              width: 1.5,
                            ),
                          ),
                          title: Text(
                            'Delete Section "$sectionKey"?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          content: Text(
                            'Selected section will be permanently deleted.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
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
                              onPressed: () async {
                                // Find the section to delete
                                final sectionToDelete = taskSections.firstWhere(
                                  (section) => section.name == sectionKey,
                                  orElse:
                                      () =>
                                          throw Exception('Section not found'),
                                );

                                // Store original state for rollback
                                final originalTaskSections =
                                    List<TaskSection>.from(taskSections);
                                final originalSections =
                                    Map<String, List<ToDoItem>>.from(sections);
                                final originalCompletedSections =
                                    Map<String, List<ToDoItem>>.from(
                                      completedSections,
                                    );

                                // Step 1: Update local state immediately (remove section)
                                setState(() {
                                  taskSections.removeWhere(
                                    (s) => s.id == sectionToDelete.id,
                                  );
                                  sections.remove(sectionKey);
                                  completedSections.remove(sectionKey);
                                });

                                if (mounted) {
                                  Navigator.pop(context);
                                }

                                // Step 2: Perform database operation
                                try {
                                  final success =
                                      await TasksAdapter.deleteSection(
                                        sectionToDelete.id,
                                      );

                                  if (!success) {
                                    throw Exception(
                                      'Database operation failed',
                                    );
                                  }

                                  // Step 3: Show success message
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Section "$sectionKey" deleted successfully',
                                        ),
                                        backgroundColor:
                                            Theme.of(
                                              context,
                                            ).colorScheme.tertiary,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  // Step 4: Revert local state if database operation failed
                                  setState(() {
                                    taskSections.clear();
                                    taskSections.addAll(originalTaskSections);
                                    sections.clear();
                                    sections.addAll(originalSections);
                                    completedSections.clear();
                                    completedSections.addAll(
                                      originalCompletedSections,
                                    );
                                  });

                                  // Step 5: Show error message
                                  print('Error deleting section: $e');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to delete section: $e',
                                        ),
                                        backgroundColor:
                                            Theme.of(context).colorScheme.error,
                                      ),
                                    );
                                  } // Reload data to ensure consistency
                                  _loadTasksFromDatabase();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(
                                'Delete',
                                style: TextStyle(fontFamily: 'Poppins'),
                              ),
                            ),
                          ],
                        ),
                  );
                },
                icon: Icon(
                  !empty
                      ? collapseSection
                          ? Icons.chevron_left
                          : Icons.expand_more
                      : Icons.delete_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        ),
        if (addingItemInSection == sectionKey) ...[
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 36, vertical: 5),
            decoration: standardTile(10),
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 2),
              leading: IconButton(
                alignment: Alignment.centerLeft,
                onPressed: clearItem,
                icon: Icon(
                  Icons.close,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 20,
                ),
              ),
              title: SizedBox(
                child: TextField(
                  controller: textController,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  cursorColor: Theme.of(context).colorScheme.tertiary,
                  decoration: InputDecoration(
                    hintText: 'Details',
                    labelText: 'Details*',
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondary,
                    ),
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondary,
                    ),
                    border: const UnderlineInputBorder(),
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
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      label: Text(
                        selectedDate != null
                            ? DateFormatter.formatDate(selectedDate!)
                            : "Pick date",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
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
                          builder: DateFormatter.datePickerBuilder,
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
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      label: Text(
                        selectedTime != null
                            ? DateFormatter.formatTimeOfDay(selectedTime!)
                            : "Pick time",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 12,
                        ),
                      ),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime ?? TimeOfDay.now(),
                          initialEntryMode: TimePickerEntryMode.dial,
                        );
                        if (picked != null) {
                          setState(() {
                            selectedTime = picked;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              trailing: IconButton(
                alignment: Alignment.centerRight,
                onPressed: () async {
                  if (selectedDate != null &&
                      selectedTime != null &&
                      textController.text.isNotEmpty) {
                    try {
                      final deadline = DateTime(
                        selectedDate!.year,
                        selectedDate!.month,
                        selectedDate!.day,
                        selectedTime!.hour,
                        selectedTime!.minute,
                      ); // Find the section ID
                      final section = taskSections.firstWhere(
                        (s) => s.name == sectionKey,
                        orElse: () => throw Exception('Section not found'),
                      );

                      // Check if this is a project section to set projectId
                      final isProjectSection =
                          section.type == SectionType.projectLinked;

                      // Implement optimistic task creation
                      final tempTask = ToDoItem(
                        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
                        sectionId: section.id,
                        projectId: isProjectSection ? section.projectId : null,
                        text: textController.text.trim(),
                        deadlineDate: deadline,
                        isCompleted: false,
                        completedAt: null,
                      );

                      // Ensure the section exists in our local state
                      if (sections[sectionKey] == null) {
                        sections[sectionKey] = [];
                      }

                      // Use OptimisticUpdates service for task creation
                      await OptimisticUpdates.performListOperation<ToDoItem>(
                        list: sections[sectionKey]!,
                        item: tempTask,
                        operation: 'add',
                        databaseOperation: () async {
                          return await TasksAdapter.createTask(
                            section.id,
                            textController.text.trim(),
                            deadline,
                          );
                        },
                        onSuccess: () {
                          // Sort the list after adding
                          setState(() {
                            sections[sectionKey]!.sort((a, b) {
                              if (a.deadlineDate.isBefore(b.deadlineDate)) {
                                return -1;
                              }
                              if (a.deadlineDate.isAfter(b.deadlineDate)) {
                                return 1;
                              }
                              return 0;
                            });
                          });

                          // If this is a project section, sync the task back to the project
                          if (isProjectSection && section.projectId != null) {
                            ProjectTasksSync.syncTaskToProject(
                              projectId: section.projectId!,
                              taskText: textController.text.trim(),
                              taskDeadline: deadline,
                            );
                          }

                          // Reload data to get the real task ID from database
                          _loadTasksFromDatabase();
                        },
                        showSuccessMessage:
                            'Task "${textController.text.trim()}" created successfully',
                        showErrorMessage: 'Failed to create task',
                        context: context,
                      );

                      // Clear form
                      setState(() {
                        addingItemInSection = null;
                        textController.clear();
                        selectedDate = null;
                        selectedTime = null;
                      });
                    } catch (e) {
                      print('Error creating task: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to create task: $e'),
                            backgroundColor:
                                Theme.of(context).colorScheme.error,
                          ),
                        );
                      }
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'All fields are required',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onError,
                          ),
                        ),
                        backgroundColor: Theme.of(context).colorScheme.error,
                        duration: Duration(seconds: 2),
                        showCloseIcon: true,
                        closeIconColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                    );
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
        if (!collapseSection) ...[
          buildToDoItemTiles(
            context,
            sectionKey,
            (completed ? completedSections : sections)[sectionKey]!,
            completed,
          ),
        ],
      ],
    );
  }

  // Helper method to build tab chips with Events-style design (matching Projects)
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

  void deleteSelected() async {
    // Collect tasks to delete and store original state
    List<String> taskIdsToDelete = [];
    Map<String, List<ToDoItem>> originalSections = {};
    Map<String, List<ToDoItem>> originalCompletedSections = {};
    List<ToDoItem> projectTasksToSync = []; // Track project tasks for syncing

    // Store original state and collect task IDs
    for (final sectionName in selectedTaskIDs.keys) {
      final taskIds = selectedTaskIDs[sectionName] ?? {};
      taskIdsToDelete.addAll(
        taskIds,
      ); // Find the section info to check if it's a project section
      final section = taskSections.firstWhere(
        (s) => s.name == sectionName,
        orElse:
            () => TaskSection(
              id: '',
              name: sectionName,
              isCompleted: false,
              type: SectionType.userCreated,
            ),
      );

      // Store original lists for rollback
      if (sections[sectionName] != null) {
        originalSections[sectionName] = List.from(sections[sectionName]!);

        // If this is a project section, collect tasks that need syncing
        if (section.type == SectionType.projectLinked &&
            section.projectId != null) {
          final tasksInSection = sections[sectionName]!;
          for (final taskId in taskIds) {
            try {
              final task = tasksInSection.firstWhere((t) => t.id == taskId);
              projectTasksToSync.add(task);
            } catch (e) {
              // Task might not be found in this section, continue
            }
          }
        }
      }
      if (completedSections[sectionName] != null) {
        originalCompletedSections[sectionName] = List.from(
          completedSections[sectionName]!,
        );

        // If this is a project section, collect completed tasks that need syncing
        if (section.type == SectionType.projectLinked &&
            section.projectId != null) {
          final tasksInSection = completedSections[sectionName]!;
          for (final taskId in taskIds) {
            try {
              final task = tasksInSection.firstWhere((t) => t.id == taskId);
              projectTasksToSync.add(task);
            } catch (e) {
              // Task might not be found in this section, continue
            }
          }
        }
      }
    }

    if (taskIdsToDelete.isEmpty) return;

    // Step 1: Update local state immediately (remove tasks)
    setState(() {
      for (final sectionName in selectedTaskIDs.keys) {
        final taskIds = selectedTaskIDs[sectionName] ?? {};

        // Remove from both todo and completed sections
        sections[sectionName]?.removeWhere((task) => taskIds.contains(task.id));
        completedSections[sectionName]?.removeWhere(
          (task) => taskIds.contains(task.id),
        );
      }
      selectedTaskIDs.clear();
    });

    // Step 2: Perform database operation
    try {
      final success = await TasksAdapter.deleteTasks(taskIdsToDelete);

      if (!success) {
        throw Exception('Database operation failed');
      }

      // Step 2.5: Sync deletions back to projects for project tasks
      for (final task in projectTasksToSync) {
        if (task.projectId != null && task.projectId!.isNotEmpty) {
          try {
            await ProjectTasksSync.syncTaskDeletionToProject(
              taskId: task.id,
              projectId: task.projectId!,
            );
          } catch (e) {
            print('Error syncing task deletion to project: $e');
            // Continue with other tasks even if one fails
          }
        }
      }

      // Step 3: Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${taskIdsToDelete.length} tasks deleted successfully',
            ),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
          ),
        );
      }
    } catch (e) {
      // Step 4: Revert local state if database operation failed
      setState(() {
        // Restore original lists
        sections.addAll(originalSections);
        completedSections.addAll(originalCompletedSections);
        selectedTaskIDs.clear();
      });

      // Step 5: Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete tasks: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }

      // Reload data to ensure consistency
      _loadTasksFromDatabase();
    }
  }

  void selectAllFromSections() {
    setState(() {
      final targetMap = openCompleted ? completedSections : sections;
      for (final sectionKey in selectedTaskIDs.keys.toList()) {
        if (selectedTaskIDs[sectionKey]?.isNotEmpty ?? false) {
          for (final item in targetMap[sectionKey]!) {
            selectedTaskIDs[sectionKey]!.add(item.id);
          }
        }
      }
    });
  }

  bool areAllSelectedFromSection() {
    final targetMap = openCompleted ? completedSections : sections;

    for (final sectionKey in targetMap.keys) {
      final sectionSelectedIDs = selectedTaskIDs[sectionKey] ?? {};
      final sectionTaskIDs =
          targetMap[sectionKey]!.map((item) => item.id).toSet();

      if (sectionSelectedIDs.isNotEmpty) {
        if (!sectionTaskIDs.every((id) => sectionSelectedIDs.contains(id))) {
          return false;
        }
      }
    }
    return true;
  }

  void completeOrUncomplete() async {
    // Collect all selected task IDs and their original state
    Set<String> allSelectedIDs = {};
    Map<String, List<ToDoItem>> originalSections = {};
    Map<String, List<ToDoItem>> originalCompletedSections = {};

    for (final sectionKey in selectedTaskIDs.keys) {
      allSelectedIDs.addAll(selectedTaskIDs[sectionKey] ?? {});

      // Store original state for rollback
      if (sections[sectionKey] != null) {
        originalSections[sectionKey] = List.from(sections[sectionKey]!);
      }
      if (completedSections[sectionKey] != null) {
        originalCompletedSections[sectionKey] = List.from(
          completedSections[sectionKey]!,
        );
      }
    }

    if (allSelectedIDs.isEmpty) return;

    // Determine the new completion status
    final newCompletionStatus = !openCompleted;

    // Step 1: Update local state immediately
    setState(() {
      for (final taskId in allSelectedIDs) {
        // Find the task and move it between sections
        for (final sectionKey in selectedTaskIDs.keys) {
          if (selectedTaskIDs[sectionKey]?.contains(taskId) ?? false) {
            if (openCompleted) {
              // Moving from completed to todo
              final task = completedSections[sectionKey]?.firstWhere(
                (t) => t.id == taskId,
              );
              if (task != null) {
                completedSections[sectionKey]?.removeWhere(
                  (t) => t.id == taskId,
                );
                if (sections[sectionKey] == null) {
                  sections[sectionKey] = [];
                }
                final updatedTask = task.copyWith(
                  isCompleted: false,
                  completedAt: null,
                );
                sections[sectionKey]!.add(updatedTask);

                // Sort by deadline
                sections[sectionKey]!.sort((a, b) {
                  if (a.deadlineDate.isBefore(b.deadlineDate)) return -1;
                  if (a.deadlineDate.isAfter(b.deadlineDate)) return 1;
                  return 0;
                });
              }
            } else {
              // Moving from todo to completed
              final task = sections[sectionKey]?.firstWhere(
                (t) => t.id == taskId,
              );
              if (task != null) {
                sections[sectionKey]?.removeWhere((t) => t.id == taskId);
                if (completedSections[sectionKey] == null) {
                  completedSections[sectionKey] = [];
                }
                final updatedTask = task.copyWith(
                  isCompleted: true,
                  completedAt: DateTime.now(),
                );
                completedSections[sectionKey]!.insert(0, updatedTask);
              }
            }
            break;
          }
        }
      }
      selectedTaskIDs.clear();
    }); // Step 2: Perform database operations
    try {
      for (final taskId in allSelectedIDs) {
        await TasksAdapter.updateTaskCompletion(taskId, newCompletionStatus);

        // Step 2.5: Sync completion back to project if this is a project task
        // Find the task to get its projectId
        for (final sectionKey in selectedTaskIDs.keys) {
          final tasks =
              openCompleted
                  ? completedSections[sectionKey]
                  : sections[sectionKey];
          final task = tasks?.firstWhere(
            (t) => t.id == taskId,
            orElse:
                () => ToDoItem(
                  id: '',
                  sectionId: '',
                  text: '',
                  deadlineDate: DateTime.now(),
                  isCompleted: false,
                ),
          );
          if (task != null &&
              task.projectId != null &&
              task.projectId!.isNotEmpty) {
            await ProjectTasksSync.syncTaskCompletionToProject(
              taskId: taskId,
              projectId: task.projectId!,
              isCompleted: newCompletionStatus,
            );
          }
        }
      }

      // Step 3: Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newCompletionStatus
                  ? 'Tasks marked as completed'
                  : 'Tasks marked as incomplete',
            ),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
          ),
        );
      }
    } catch (e) {
      // Step 4: Revert local state if database operation failed
      setState(() {
        // Restore original state
        sections.clear();
        sections.addAll(originalSections);
        completedSections.clear();
        completedSections.addAll(originalCompletedSections);
        selectedTaskIDs.clear();
      });

      // Step 5: Show error message
      print('Error updating task completion: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update tasks: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }

      // Reload data to ensure consistency
      _loadTasksFromDatabase();
    }
  }

  /// Check if we should show a separator before this section
  bool _shouldShowSeparator(int index, bool completed) {
    if (index == 0) return false; // Never show separator before first section

    List<String> sectionKeys =
        completed ? completedSections.keys.toList() 
          : sections.keys.toList();
    if (index >= sectionKeys.length) return false;

    // Find the current and previous sections
    final currentSectionName = sectionKeys[index];
    final previousSectionName = sectionKeys[index - 1];

    final currentSection = taskSections.firstWhere(
      (s) => s.name == currentSectionName,
      orElse:
          () =>
              TaskSection(id: '', name: currentSectionName, isCompleted: false),
    );
    final previousSection = taskSections.firstWhere(
      (s) => s.name == previousSectionName,
      orElse:
          () => TaskSection(
            id: '',
            name: previousSectionName,
            isCompleted: false,
          ),
    );

    // Show separator when transitioning from user sections to project sections
    return previousSection.type == SectionType.userCreated &&
        currentSection.type == SectionType.projectLinked;
  }

  /// Build visual separator between user and project sections
  Widget _buildSectionSeparator() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                border: Border.all(
                  width: 1,
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'PROJECTS',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onPrimary.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                border: Border.all(
                  width: 1,
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while data is being loaded
    if (isLoading) {
      return Scaffold(
        extendBodyBehindAppBar: false,
        backgroundColor: Theme.of(context).colorScheme.primary,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                SizedBox(height: 16),
                Text(
                  'Fetching tasks...',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    allSelectedFromSection = areAllSelectedFromSection();
    final filteredSectionKeys =
        sections.keys
            .where((key) => key.toLowerCase().contains(searchQuery))
            .toList();
    final filteredCompletedSectionKeys =
        completedSections.keys
            .where((key) => key.toLowerCase().contains(searchQuery))
            .toList();
    return Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: Stack(
          children: [
            // Purple blob 1 - Top left, small and playful
            Positioned(
              top: 60,
              left: -20,
              child: Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary.withValues(
                    alpha: 0.7,
                  ), // Slightly more visible for tasks
                  borderRadius: BorderRadius.circular(80),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 55, sigmaY: 40),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            // Purple blob 2 - Diagonal middle right, medium
            Positioned(
              top: MediaQuery.of(context).size.height * 0.25,
              right: -40,
              child: Container(
                width: 160,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.6),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 75, sigmaY: 75),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            // Purple blob 3 - Diagonal lower left, large and dreamy
            Positioned(
              top: MediaQuery.of(context).size.height * 0.5,
              left: -60,
              child: Container(
                width: 200,
                height: 180,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.4), // More subtle
                  borderRadius: BorderRadius.circular(90),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 85, sigmaY: 70),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            // Purple blob 4 - Bottom right corner, small accent
            Positioned(
              bottom: -30,
              right: 20,
              child: Container(
                width: 110,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.5),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
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
                              child: Text(
                                'Tasks',
                                style: TextStyle(
                                  fontSize: 28,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
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
                                          hintText: 'Search tasks...',
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
                            margin: EdgeInsets.only(right: 20),
                            child: Row(
                              children: [
                                if (areSelectedTasksEmpty()) ...[
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
                                        size: 30,
                                      ),
                                      onPressed: () => _showSectionDialog(),
                                    ),
                                  ],
                                ] else ...[
                                  IconButton(
                                    icon: Icon(
                                      // ignore: dead_code
                                      allSelectedFromSection
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
                                        if (allSelectedFromSection) {
                                          selectedTaskIDs.clear();
                                        } else {
                                          selectAllFromSections();
                                        }
                                      });
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      // ignore: dead_code
                                      Icons.check,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                      size: 26,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        completeOrUncomplete();
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
                                      showDialog(
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
                                                      Theme.of(
                                                        context,
                                                      ).colorScheme.onSecondary,
                                                  width: 1.5,
                                                ),
                                              ),
                                              title: Text(
                                                'Delete Tasks?',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      Theme.of(
                                                        context,
                                                      ).colorScheme.onPrimary,
                                                ),
                                              ),
                                              content: Text(
                                                'Selected tasks will be permanently deleted.',
                                                style: TextStyle(
                                                  color:
                                                      Theme.of(
                                                        context,
                                                      ).colorScheme.onPrimary,
                                                ),
                                              ),
                                              actions: [
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
                                                      fontFamily: 'Poppins',
                                                    ),
                                                  ),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () {
                                                    deleteSelected();
                                                    Navigator.pop(context);
                                                  },
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.red,
                                                        foregroundColor:
                                                            Colors.white,
                                                      ),
                                                  child: Text(
                                                    'Delete',
                                                    style: TextStyle(
                                                      fontFamily: 'Poppins',
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                      );
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
                  // Tab selector for To-Do vs Completed tasks (exact copy from Events)
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTabChip(
                            label: "To-Do",
                            isSelected: !openCompleted,
                            onTap: () {
                              setState(() {
                                openCompleted = false;
                                selectedTaskIDs.clear();
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildTabChip(
                            label: "Completed",
                            isSelected: openCompleted,
                            onTap: () {
                              setState(() {
                                openCompleted = true;
                                selectedTaskIDs.clear();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!openCompleted) ...[
                    if (addingSection) ...[
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
                            onPressed: clearItem,
                            icon: Icon(
                              Icons.close,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 20,
                            ),
                          ),
                          title: TextField(
                            controller: sectionName,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                            cursorColor: Theme.of(context).colorScheme.tertiary,
                            decoration: InputDecoration(
                              hintText: 'New Section',
                              labelText: 'New Section',
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
                          trailing: IconButton(
                            alignment: Alignment.centerRight,
                            onPressed: () async {
                              if (sectionName.text.isNotEmpty) {
                                try {
                                  // Check if section already exists
                                  if (taskSections.any(
                                    (section) =>
                                        section.name == sectionName.text,
                                  )) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Section "${sectionName.text}" already exists.',
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
                                        showCloseIcon: true,
                                        closeIconColor:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onPrimary,
                                      ),
                                    );
                                    return;
                                  } // Implement optimistic section creation
                                  final tempSection = TaskSection(
                                    id:
                                        'temp_${DateTime.now().millisecondsSinceEpoch}',
                                    name: sectionName.text.trim(),
                                    isCompleted: false,
                                  );

                                  // Step 1: Update local state immediately
                                  setState(() {
                                    taskSections.add(tempSection);
                                    sections[sectionName.text.trim()] =
                                        []; // Create empty section
                                    addingSection = false;
                                    sectionName.clear();
                                  });

                                  // Step 2: Perform database operation
                                  try {
                                    final success =
                                        await TasksAdapter.createSection(
                                          tempSection.name,
                                        );

                                    if (!success) {
                                      throw Exception(
                                        'Database operation failed',
                                      );
                                    }

                                    // Step 3: Reload data to get real section ID
                                    await _loadTasksFromDatabase();

                                    // Step 4: Show success message
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Section "${tempSection.name}" created successfully',
                                          ),
                                          backgroundColor:
                                              Theme.of(
                                                context,
                                              ).colorScheme.tertiary,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    // Step 5: Revert local state if database operation failed
                                    setState(() {
                                      taskSections.removeWhere(
                                        (section) =>
                                            section.id == tempSection.id,
                                      );
                                      sections.remove(tempSection.name);
                                      addingSection = false;
                                      sectionName.clear();
                                    });

                                    // Step 6: Show error message
                                    print('Error creating section: $e');
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to create section: $e',
                                          ),
                                          backgroundColor:
                                              Theme.of(
                                                context,
                                              ).colorScheme.error,
                                        ),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  print('Error creating section: $e');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to create section: $e',
                                        ),
                                        backgroundColor:
                                            Theme.of(context).colorScheme.error,
                                      ),
                                    );
                                  }
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Section Name not entered.',
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
                                    showCloseIcon: true,
                                    closeIconColor:
                                        Theme.of(context).colorScheme.onPrimary,
                                  ),
                                );
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
                    Expanded(
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        children: [
                          if (!searching) ...[
                            if (sections.isNotEmpty) ...[
                              for (
                                int i = 0;
                                i < sections.keys.length;
                                i++
                              ) ...[
                                // Add separator between user and project sections
                                if (i > 0 && _shouldShowSeparator(i, false))
                                  _buildSectionSeparator(),
                                buildSectionWidget(i, false),
                              ],
                            ],
                          ] else ...[
                            for (
                              int i = 0;
                              i < filteredSectionKeys.length;
                              i++
                            ) ...[
                              buildSectionWidget(
                                sections.keys.toList().indexOf(
                                  filteredSectionKeys[i],
                                ),
                                false,
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ] else ...[
                    if (completedSections.isNotEmpty) ...[
                      Expanded(
                        child: ListView(
                          children: [
                            if (!searching) ...[
                              for (
                                int i = 0;
                                i < completedSections.keys.length;
                                i++
                              ) ...[
                                // Add separator between user and project sections
                                if (i > 0 && _shouldShowSeparator(i, true))
                                  _buildSectionSeparator(),
                                buildSectionWidget(i, true),
                              ],
                            ] else ...[
                              for (
                                int i = 0;
                                i < filteredCompletedSectionKeys.length;
                                i++
                              ) ...[
                                buildSectionWidget(
                                  completedSections.keys.toList().indexOf(
                                    filteredSectionKeys[i],
                                  ),
                                  true,
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
