import 'package:flutter/material.dart';
import 'main.dart';
import 'services/tasks_adapter.dart';
import 'services/optimistic_updates.dart';
import 'utils/date_formatter.dart';

class TasksWithMongoDB extends StatefulWidget {
  const TasksWithMongoDB({super.key});

  @override
  State<TasksWithMongoDB> createState() => _TasksWithMongoDBState();
}

class _TasksWithMongoDBState extends State<TasksWithMongoDB> {
  // Data structures
  Map<String, List<ToDoItem>> sections = {};
  Map<String, List<ToDoItem>> completedSections = {};
  List<TaskSection> taskSections = [];

  // UI state
  String? addingItemInSection;
  bool addingSection = false;
  List<String> collapsedSections = [];
  bool openCompleted = false;
  Map<String, Set<String>> selectedTaskIDs = {}; // Changed from int to String
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

        if (todoTasks.isNotEmpty) {
          sections[section.name] = todoTasks;
        }
        if (completedTasks.isNotEmpty) {
          completedSections[section.name] = completedTasks;
        }
      }
    } catch (e) {
      print('Error loading tasks from database: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load tasks: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }

    try {
      // Load sections
      taskSections = await TasksAdapter.loadSections();

      // Load all tasks
      final allTasks =
          await TasksAdapter.loadTasks(); // Organize tasks into sections and completed sections
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

        if (todoTasks.isNotEmpty) {
          sections[section.name] = todoTasks;
        }
        if (completedTasks.isNotEmpty) {
          completedSections[section.name] = completedTasks;
        }
      }

      print(
        "TasksWithMongoDB: Loaded ${taskSections.length} sections and ${allTasks.length} tasks",
      );
    } catch (e) {
      print("TasksWithMongoDB: Error loading tasks: $e");
      _showSnackBar("Failed to load tasks: $e", isError: true);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Show a snackbar message
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.onError),
        ),
        backgroundColor:
            isError
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.tertiary,
        duration: Duration(seconds: 2),
        showCloseIcon: true,
        closeIconColor: Theme.of(context).colorScheme.onPrimary,
      ),
    );
  }

  /// Create a new section in MongoDB with optimistic updates
  Future<void> _createSection(String sectionName) async {
    // Create temporary section for optimistic update
    final tempSection = TaskSection(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      name: sectionName,
      isCompleted: false,
    );

    // Step 1: Update local state immediately
    setState(() {
      taskSections.add(tempSection);
      sections[sectionName] = []; // Create empty section
    });

    // Step 2: Perform database operation
    try {
      final success = await TasksAdapter.createSection(sectionName);

      if (!success) {
        throw Exception('Database operation failed');
      }

      // Step 3: Reload data to get real section ID
      await _loadTasksFromDatabase();

      // Step 4: Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Section "$sectionName" created successfully'),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
          ),
        );
      }
    } catch (e) {
      // Step 5: Revert local state if database operation failed
      setState(() {
        taskSections.removeWhere((section) => section.id == tempSection.id);
        sections.remove(sectionName);
      });

      // Step 6: Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create section: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Delete a section and all its tasks from MongoDB with optimistic updates
  Future<void> _deleteSection(String sectionName) async {
    // Store original state for rollback
    final originalTaskSections = List<TaskSection>.from(taskSections);
    final originalSections = Map<String, List<ToDoItem>>.from(sections);
    final originalCompletedSections = Map<String, List<ToDoItem>>.from(
      completedSections,
    );

    try {
      // Find the section ID by name
      final section = taskSections.firstWhere(
        (s) => s.name == sectionName,
        orElse: () => throw Exception('Section not found'),
      );

      // Step 1: Update local state immediately (remove section)
      setState(() {
        taskSections.removeWhere((s) => s.id == section.id);
        sections.remove(sectionName);
        completedSections.remove(sectionName);
      });

      // Step 2: Perform database operation
      final success = await TasksAdapter.deleteSection(section.id);

      if (!success) {
        throw Exception('Database operation failed');
      }

      // Step 3: Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Section "$sectionName" deleted successfully'),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
          ),
        );
      }
    } catch (e) {
      // Step 4: Revert local state if database operation failed
      setState(() {
        // Restore original state
        taskSections.clear();
        taskSections.addAll(originalTaskSections);
        sections.clear();
        sections.addAll(originalSections);
        completedSections.clear();
        completedSections.addAll(originalCompletedSections);
      });

      // Step 5: Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete section: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }

      // Reload data to ensure consistency
      _loadTasksFromDatabase();
    }
  }

  /// Create a new task in MongoDB with optimistic updates
  Future<void> _createTask(
    String sectionName,
    String text,
    DateTime deadline,
  ) async {
    try {
      // Find the section ID by name
      final section = taskSections.firstWhere(
        (s) => s.name == sectionName,
        orElse: () => throw Exception('Section not found'),
      );

      // Create temporary task with optimistic ID
      final tempTask = ToDoItem(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        sectionId: section.id,
        text: text,
        deadlineDate: deadline,
        isCompleted: false,
        completedAt: null,
      );

      // Ensure the section exists in our local state
      if (sections[sectionName] == null) {
        sections[sectionName] = [];
      } // Use optimistic updates for task creation
      await OptimisticUpdates.performListOperation<ToDoItem>(
        list: sections[sectionName]!,
        item: tempTask,
        operation: 'add',
        databaseOperation: () async {
          final success = await TasksAdapter.createTask(
            section.id,
            text,
            deadline,
          );
          return success;
        },
        onSuccess: () {
          // Sort the list after adding
          setState(() {
            sections[sectionName]!.sort((a, b) {
              if (a.deadlineDate.isBefore(b.deadlineDate)) return -1;
              if (a.deadlineDate.isAfter(b.deadlineDate)) return 1;
              return 0;
            });
          });
          // Reload data to get the real task ID from database
          _loadTasksFromDatabase();
        },
        showSuccessMessage: 'Task "$text" created successfully',
        showErrorMessage: 'Failed to create task',
        context: context,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create task: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  /// Toggle task completion status in MongoDB with optimistic updates
  Future<void> _toggleTaskCompletion(ToDoItem task) async {
    // Store original state for rollback
    String? originalSectionName;
    List<ToDoItem>? originalSourceList;
    int originalIndex = -1;

    // Find which section contains this task
    for (final entry in sections.entries) {
      final index = entry.value.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        originalSectionName = entry.key;
        originalSourceList = List.from(entry.value);
        originalIndex = index;
        break;
      }
    }

    if (originalSectionName == null) {
      for (final entry in completedSections.entries) {
        final index = entry.value.indexWhere((t) => t.id == task.id);
        if (index != -1) {
          originalSectionName = entry.key;
          originalSourceList = List.from(entry.value);
          originalIndex = index;
          break;
        }
      }
    }

    if (originalSectionName == null || originalIndex == -1) {
      _showSnackBar('Task not found', isError: true);
      return;
    }

    final sectionName =
        originalSectionName; // Make non-nullable for use in setState

    // Step 1: Update local state immediately
    setState(() {
      if (task.isCompleted) {
        // Moving from completed to todo
        completedSections[sectionName]?.removeAt(originalIndex);
        if (sections[sectionName] == null) {
          sections[sectionName] = [];
        }
        final updatedTask = task.copyWith(
          isCompleted: false,
          completedAt: null,
        );
        sections[sectionName]!.add(updatedTask);

        // Sort the todo tasks by deadline
        sections[sectionName]!.sort((a, b) {
          if (a.deadlineDate.isBefore(b.deadlineDate)) return -1;
          if (a.deadlineDate.isAfter(b.deadlineDate)) return 1;
          return 0;
        });
      } else {
        // Moving from todo to completed
        sections[sectionName]?.removeAt(originalIndex);
        if (completedSections[sectionName] == null) {
          completedSections[sectionName] = [];
        }
        final updatedTask = task.copyWith(
          isCompleted: true,
          completedAt: DateTime.now(),
        );
        completedSections[sectionName]!.insert(
          0,
          updatedTask,
        ); // Add to front (most recent)
      }
    });

    // Step 2: Perform database operation
    try {
      final success = await TasksAdapter.updateTaskCompletion(
        task.id,
        !task.isCompleted,
      );

      if (!success) {
        throw Exception('Database operation failed');
      }

      // Step 3: Show success message
      _showSnackBar(
        task.isCompleted
            ? 'Task marked as incomplete'
            : 'Task marked as complete',
        isError: false,
      );
    } catch (error) {
      // Step 4: Revert local state if database operation failed
      setState(() {
        if (task.isCompleted) {
          // Revert: put task back in completed list
          sections[sectionName]?.removeWhere((t) => t.id == task.id);
          if (originalSourceList != null) {
            completedSections[sectionName] = originalSourceList;
          }
        } else {
          // Revert: put task back in todo list
          completedSections[sectionName]?.removeWhere((t) => t.id == task.id);
          if (originalSourceList != null) {
            sections[sectionName] = originalSourceList;
          }
        }
      });

      // Step 5: Show error message
      _showSnackBar('Failed to update task completion', isError: true);

      // Reload data to ensure consistency
      _loadTasksFromDatabase();
    }
  }

  /// Delete selected tasks from MongoDB with optimistic updates
  Future<void> _deleteSelectedTasks() async {
    // Collect tasks to delete and store original state
    List<String> taskIdsToDelete = [];
    Map<String, List<ToDoItem>> originalSections = {};
    Map<String, List<ToDoItem>> originalCompletedSections = {};

    // Store original state and collect task IDs
    for (final sectionName in selectedTaskIDs.keys) {
      final taskIds = selectedTaskIDs[sectionName] ?? {};
      taskIdsToDelete.addAll(taskIds);

      // Store original lists for rollback
      if (sections[sectionName] != null) {
        originalSections[sectionName] = List.from(sections[sectionName]!);
      }
      if (completedSections[sectionName] != null) {
        originalCompletedSections[sectionName] = List.from(
          completedSections[sectionName]!,
        );
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
      selectedDate = null;
      selectedTime = null;
      textController.clear();
      sectionName.clear();
    });
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
        bool pastDeadline = toDoItem.isPastDeadline;
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
                  onPressed: () => _toggleTaskCompletion(toDoItem),
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
                    setState(() {
                      addingItemInSection = sectionKey;
                    });
                  }
                },
                onLongPress:
                    () => _showDeleteSectionDialog(sectionKey, completed),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (!completed)
                      Icon(
                        Icons.add,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 20,
                      ),
                    Text(
                      sectionKey,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
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
                    _showDeleteSectionDialog(sectionKey, completed);
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
          _buildAddTaskWidget(sectionKey),
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

  Widget _buildAddTaskWidget(String sectionKey) {
    return Container(
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
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
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
                    initialEntryMode: TimePickerEntryMode.inputOnly,
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
              final deadline = DateTime(
                selectedDate!.year,
                selectedDate!.month,
                selectedDate!.day,
                selectedTime!.hour,
                selectedTime!.minute,
              );

              await _createTask(sectionKey, textController.text, deadline);
              clearItem();
            } else {
              _showSnackBar('All fields are required', isError: true);
            }
          },
          icon: Icon(
            Icons.check,
            color: Theme.of(context).colorScheme.onPrimary,
            size: 20,
          ),
        ),
      ),
    );
  }

  void _showDeleteSectionDialog(String sectionKey, bool completed) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.primary,
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
                    onPressed: () async {
                      Navigator.pop(context);
                      await _deleteSection(sectionKey);
                    },
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
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.primary,
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      );
    }

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
        child: Container(
          color: Theme.of(context).colorScheme.primary,
          child: Column(
            children: [
              // Header
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
                            'Tasks (MongoDB)',
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
                                    labelText: 'Search for a Section',
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
                            if (areSelectedTasksEmpty()) ...[
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
                                    size: 30,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      addingSection = true;
                                      openCompleted = false;
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.refresh,
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                    size: 26,
                                  ),
                                  onPressed: _loadTasksFromDatabase,
                                ),
                              ],
                            ] else ...[
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                  size: 28,
                                ),
                                onPressed: () => _showDeleteTasksDialog(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Filter chips
              Container(
                margin: EdgeInsets.only(left: 10, right: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    singleFilterChip(
                      label: "To-Do",
                      isSelected: !openCompleted,
                      onTap: () {
                        setState(() {
                          openCompleted = false;
                          selectedTaskIDs.clear();
                        });
                      },
                    ),
                    singleFilterChip(
                      label: "Completed",
                      isSelected: openCompleted,
                      onTap: () {
                        setState(() {
                          openCompleted = true;
                          selectedTaskIDs.clear();
                        });
                      },
                    ),
                  ],
                ),
              ),

              // Content
              if (!openCompleted) ...[
                if (addingSection) ...[_buildAddSectionWidget()],
                Expanded(
                  child: ListView(
                    children: [
                      if (!searching) ...[
                        if (sections.isNotEmpty) ...[
                          for (int i = 0; i < sections.keys.length; i++) ...[
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
                          ) ...[buildSectionWidget(i, true)],
                        ] else ...[
                          for (
                            int i = 0;
                            i < filteredCompletedSectionKeys.length;
                            i++
                          ) ...[
                            buildSectionWidget(
                              completedSections.keys.toList().indexOf(
                                filteredCompletedSectionKeys[i],
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
      ),
    );
  }

  Widget _buildAddSectionWidget() {
    return Container(
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
        title: TextField(
          controller: sectionName,
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
          cursorColor: Theme.of(context).colorScheme.tertiary,
          decoration: InputDecoration(
            hintText: 'New Section',
            labelText: 'New Section',
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
            if (sectionName.text.isNotEmpty) {
              if (!sections.containsKey(sectionName.text)) {
                await _createSection(sectionName.text);
                clearItem();
              } else {
                _showSnackBar(
                  'Section "${sectionName.text}" already exists.',
                  isError: true,
                );
              }
            } else {
              _showSnackBar('Section Name not entered.', isError: true);
            }
          },
          icon: Icon(
            Icons.check,
            color: Theme.of(context).colorScheme.onPrimary,
            size: 20,
          ),
        ),
      ),
    );
  }

  void _showDeleteTasksDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: Theme.of(context).colorScheme.onSecondary,
                width: 1.5,
              ),
            ),
            title: Text(
              'Delete Selected Tasks?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            content: Text(
              'Selected tasks will be permanently deleted.',
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
                    onPressed: () async {
                      Navigator.pop(context);
                      await _deleteSelectedTasks();
                    },
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
}
