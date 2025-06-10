import 'package:flutter/material.dart';
import 'main.dart';
import 'services/tasks_adapter.dart';
import 'services/optimistic_updates.dart';

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
      final allTasks =
          await TasksAdapter.loadTasks(); // Organize tasks by section
      sections.clear();
      completedSections.clear();

      for (final section in taskSections) {
        final sectionTasks =
            allTasks.where((task) => task.sectionId == section.id).toList();
        final todoTasks =
            sectionTasks.where((task) => !task.isCompleted).toList();
        final completedTasks =
            sectionTasks
                .where((task) => task.isCompleted)
                .toList(); // Sort tasks: for ongoing tasks, sort by deadline (earliest first)
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
                    });

                    // Step 2: Perform database operation
                    try {
                      await TasksAdapter.updateTaskCompletion(
                        toDoItem.id,
                        !completed,
                      );

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
                        ? "Due Today, ${toDoItem.deadlineDate.hour.toString().padLeft(2, '0')}:${toDoItem.deadlineDate.minute.toString().padLeft(2, '0')}"
                        : "Due ${toDoItem.deadlineDate.day}/${toDoItem.deadlineDate.month}/${toDoItem.deadlineDate.year % 2000}"
                    : "Completed on ${toDoItem.deadlineDate.day}/${toDoItem.deadlineDate.month}/${toDoItem.deadlineDate.year % 2000}",
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
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: Icon(
                                    Icons.close,
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                    size: 30,
                                  ),
                                ),
                                IconButton(
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
                                      }

                                      // Reload data to ensure consistency
                                      _loadTasksFromDatabase();
                                    }
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
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  IconButton(
                                    onPressed: () => Navigator.pop(context),
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
                                        }

                                        // Reload data to ensure consistency
                                        _loadTasksFromDatabase();
                                      }
                                    },
                                    icon: Icon(
                                      Icons.check,
                                      color:
                                          Theme.of(context).colorScheme.error,
                                      size: 30,
                                    ),
                                  ),
                                ],
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: Icon(
                                    Icons.close,
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                    size: 30,
                                  ),
                                ),
                                IconButton(
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
                                      }

                                      // Reload data to ensure consistency
                                      _loadTasksFromDatabase();
                                    }
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
                            ? "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}"
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
                            ? "${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}"
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
                      );

                      // Find the section ID
                      final section = taskSections.firstWhere(
                        (s) => s.name == sectionKey,
                        orElse: () => throw Exception('Section not found'),
                      ); // Implement optimistic task creation
                      final tempTask = ToDoItem(
                        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
                        sectionId: section.id,
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
    });

    // Step 2: Perform database operations
    try {
      for (final taskId in allSelectedIDs) {
        await TasksAdapter.updateTaskCompletion(taskId, newCompletionStatus);
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
                  'Loading tasks...',
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
                            'Tasks',
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
                                      selectedSection =
                                          sections.isNotEmpty
                                              ? sections.keys.first
                                              : null;
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.more_vert,
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                    size: 26,
                                  ),
                                  onPressed: () {},
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
                                      Theme.of(context).colorScheme.onPrimary,
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
                                      Theme.of(context).colorScheme.onPrimary,
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
                            try {
                              // Check if section already exists
                              if (taskSections.any(
                                (section) => section.name == sectionName.text,
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
                                        Theme.of(context).colorScheme.onPrimary,
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
                                  throw Exception('Database operation failed');
                                }

                                // Step 3: Reload data to get real section ID
                                await _loadTasksFromDatabase();

                                // Step 4: Show success message
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
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
                                    (section) => section.id == tempSection.id,
                                  );
                                  sections.remove(tempSection.name);
                                  addingSection = false;
                                  sectionName.clear();
                                });

                                // Step 6: Show error message
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
                                        Theme.of(context).colorScheme.onError,
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
      ),
    );
  }
}
