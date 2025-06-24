import 'dart:developer';
import '../shared/mongodb.dart';
import '../shared/user_session.dart';

enum SectionType { userCreated, projectLinked }

class TaskSection {
  final String id;
  final String name;
  final bool isCompleted;
  final String? projectId; // Optional - identifies project sections
  final DateTime? lastInteracted; // For sorting
  final SectionType type; // userCreated or projectLinked

  TaskSection({
    required this.id,
    required this.name,
    required this.isCompleted,
    this.projectId,
    this.lastInteracted,
    this.type = SectionType.userCreated,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isCompleted': isCompleted,
      'projectId': projectId,
      'lastInteracted': lastInteracted?.toIso8601String(),
      'type': 'task_section',
      'sectionType': type.toString().split('.').last,
    };
  }

  static TaskSection fromMap(Map<String, dynamic> map) {
    return TaskSection(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      projectId: map['projectId'],
      lastInteracted:
          map['lastInteracted'] != null
              ? DateTime.parse(map['lastInteracted'])
              : null,
      type:
          map['sectionType'] == 'projectLinked'
              ? SectionType.projectLinked
              : SectionType.userCreated,
    );
  }

  TaskSection copyWith({
    String? id,
    String? name,
    bool? isCompleted,
    String? projectId,
    DateTime? lastInteracted,
    SectionType? type,
  }) {
    return TaskSection(
      id: id ?? this.id,
      name: name ?? this.name,
      isCompleted: isCompleted ?? this.isCompleted,
      projectId: projectId ?? this.projectId,
      lastInteracted: lastInteracted ?? this.lastInteracted,
      type: type ?? this.type,
    );
  }
}

class ToDoItem {
  final String id;
  final String sectionId;
  final String? projectId; // Optional - links task to project
  String text;
  DateTime deadlineDate;
  final bool isCompleted;
  DateTime? completedAt; // Track when the task was completed

  ToDoItem({
    required this.id,
    required this.sectionId,
    required this.text,
    required this.deadlineDate,
    required this.isCompleted,
    this.projectId, // Optional
    this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sectionId': sectionId,
      'projectId': projectId,
      'text': text,
      'deadlineDate': deadlineDate.toIso8601String(),
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
      'type': 'task_item',
    };
  }

  static ToDoItem fromMap(Map<String, dynamic> map) {
    return ToDoItem(
      id: map['id'] ?? '',
      sectionId: map['sectionId'] ?? '',
      projectId: map['projectId'], // Can be null
      text: map['text'] ?? '',
      deadlineDate: DateTime.parse(
        map['deadlineDate'] ?? DateTime.now().toIso8601String(),
      ),
      isCompleted: map['isCompleted'] ?? false,
      completedAt:
          map['completedAt'] != null
              ? DateTime.parse(map['completedAt'])
              : null,
    );
  }

  bool get isPastDeadline => deadlineDate.isBefore(DateTime.now());

  /// Create a copy of this task with updated fields
  ToDoItem copyWith({
    String? id,
    String? sectionId,
    String? projectId,
    String? text,
    DateTime? deadlineDate,
    bool? isCompleted,
    DateTime? completedAt,
  }) {
    return ToDoItem(
      id: id ?? this.id,
      sectionId: sectionId ?? this.sectionId,
      projectId: projectId ?? this.projectId,
      text: text ?? this.text,
      deadlineDate: deadlineDate ?? this.deadlineDate,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class TasksAdapter {
  static String? get userId => UserSession().userId;

  /// Load all task sections from MongoDB
  static Future<List<TaskSection>> loadSections() async {
    if (userId == null) {
      log("TasksAdapter.loadSections: No user ID available");
      return [];
    }

    try {
      final docs = await MongoDatabase.getData(
        userId: userId,
        type: 'task_section',
      );

      final sections = docs.map((doc) => TaskSection.fromMap(doc)).toList();
      log("TasksAdapter.loadSections: Loaded ${sections.length} sections");
      return sections;
    } catch (e) {
      log("TasksAdapter.loadSections: Error loading sections: $e");
      return [];
    }
  }

  /// Load all task items from MongoDB
  static Future<List<ToDoItem>> loadTasks() async {
    if (userId == null) {
      log("TasksAdapter.loadTasks: No user ID available");
      return [];
    }

    try {
      final docs = await MongoDatabase.getData(
        userId: userId,
        type: 'task_item',
      );

      final tasks = docs.map((doc) => ToDoItem.fromMap(doc)).toList();
      log("TasksAdapter.loadTasks: Loaded ${tasks.length} tasks");
      return tasks;
    } catch (e) {
      log("TasksAdapter.loadTasks: Error loading tasks: $e");
      return [];
    }
  }

  /// Create a new task section
  static Future<bool> createSection(
    String sectionName, {
    bool isCompleted = false,
  }) async {
    if (userId == null) {
      log("TasksAdapter.createSection: No user ID available");
      return false;
    }
    try {
      final sectionId = DateTime.now().millisecondsSinceEpoch.toString();
      final section = TaskSection(
        id: sectionId,
        name: sectionName,
        isCompleted: isCompleted,
        lastInteracted: DateTime.now(),
        type: SectionType.userCreated,
      );

      final success = await MongoDatabase.insertData(
        section.toMap(),
        userId: userId,
        type: 'task_section',
      );

      if (success) {
        log("TasksAdapter.createSection: Created section '$sectionName'");
      } else {
        log(
          "TasksAdapter.createSection: Failed to create section '$sectionName'",
        );
      }

      return success;
    } catch (e) {
      log("TasksAdapter.createSection: Error creating section: $e");
      return false;
    }
  }

  /// Delete a task section and all its tasks
  static Future<bool> deleteSection(String sectionId) async {
    if (userId == null) {
      log("TasksAdapter.deleteSection: No user ID available");
      return false;
    }

    try {
      // First delete all tasks in the section
      await MongoDatabase.deleteDataByQuery({
        'sectionId': sectionId,
        'type': 'task_item',
      }, userId: userId);

      // Then delete the section itself
      final success = await MongoDatabase.deleteDataByQuery({
        'id': sectionId,
        'type': 'task_section',
      }, userId: userId);

      if (success) {
        log(
          "TasksAdapter.deleteSection: Deleted section $sectionId and its tasks",
        );
      } else {
        log("TasksAdapter.deleteSection: Failed to delete section $sectionId");
      }

      return success;
    } catch (e) {
      log("TasksAdapter.deleteSection: Error deleting section: $e");
      return false;
    }
  }

  /// Create a new task item
  static Future<bool> createTask(
    String sectionId,
    String text,
    DateTime deadlineDate, {
    bool isCompleted = false,
    String? projectId, // Optional project linking
  }) async {
    if (userId == null) {
      log("TasksAdapter.createTask: No user ID available");
      return false;
    }

    try {
      final taskId = DateTime.now().millisecondsSinceEpoch.toString();
      final task = ToDoItem(
        id: taskId,
        sectionId: sectionId,
        projectId: projectId,
        text: text,
        deadlineDate: deadlineDate,
        isCompleted: isCompleted,
      );

      final success = await MongoDatabase.insertData(
        task.toMap(),
        userId: userId,
        type: 'task_item',
      );

      if (success) {
        // Update section interaction time
        await updateSectionInteraction(sectionId);

        log(
          "TasksAdapter.createTask: Created task '$text' in section $sectionId",
        );
      } else {
        log("TasksAdapter.createTask: Failed to create task '$text'");
      }

      return success;
    } catch (e) {
      log("TasksAdapter.createTask: Error creating task: $e");
      return false;
    }
  }

  /// Update a task's completion status
  static Future<bool> updateTaskCompletion(
    String taskId,
    bool isCompleted,
  ) async {
    if (userId == null) {
      log("TasksAdapter.updateTaskCompletion: No user ID available");
      return false;
    }
    try {
      final updateData = {
        'isCompleted': isCompleted,
        'completedAt': isCompleted ? DateTime.now().toIso8601String() : null,
      };

      final success = await MongoDatabase.updateDataByQuery(
        {'id': taskId, 'type': 'task_item'},
        updateData,
        userId: userId,
      );

      if (success) {
        // Get task to find its section and update section interaction
        final tasks = await loadTasks();
        final task = tasks.firstWhere(
          (t) => t.id == taskId,
          orElse: () => throw StateError('Task not found'),
        );
        await updateSectionInteraction(task.sectionId);

        log(
          "TasksAdapter.updateTaskCompletion: Updated task $taskId completion to $isCompleted",
        );
      } else {
        log("TasksAdapter.updateTaskCompletion: Failed to update task $taskId");
      }

      return success;
    } catch (e) {
      log("TasksAdapter.updateTaskCompletion: Error updating task: $e");
      return false;
    }
  }

  /// Update a task's text and deadline
  static Future<bool> updateTask(
    String taskId,
    String text,
    DateTime deadlineDate,
  ) async {
    if (userId == null) {
      log("TasksAdapter.updateTask: No user ID available");
      return false;
    }

    try {
      final success = await MongoDatabase.updateDataByQuery(
        {'id': taskId, 'type': 'task_item'},
        {'text': text, 'deadlineDate': deadlineDate.toIso8601String()},
        userId: userId,
      );

      if (success) {
        log("TasksAdapter.updateTask: Updated task $taskId");
      } else {
        log("TasksAdapter.updateTask: Failed to update task $taskId");
      }

      return success;
    } catch (e) {
      log("TasksAdapter.updateTask: Error updating task: $e");
      return false;
    }
  }

  /// Delete specific tasks by their IDs
  static Future<bool> deleteTasks(List<String> taskIds) async {
    if (userId == null) {
      log("TasksAdapter.deleteTasks: No user ID available");
      return false;
    }

    try {
      bool allSuccess = true;
      for (final taskId in taskIds) {
        final success = await MongoDatabase.deleteDataByQuery({
          'id': taskId,
          'type': 'task_item',
        }, userId: userId);
        if (!success) allSuccess = false;
      }

      if (allSuccess) {
        log("TasksAdapter.deleteTasks: Deleted ${taskIds.length} tasks");
      } else {
        log("TasksAdapter.deleteTasks: Some task deletions failed");
      }

      return allSuccess;
    } catch (e) {
      log("TasksAdapter.deleteTasks: Error deleting tasks: $e");
      return false;
    }
  }

  /// Get tasks for a specific section
  static Future<List<ToDoItem>> getTasksForSection(String sectionId) async {
    final allTasks = await loadTasks();
    return allTasks.where((task) => task.sectionId == sectionId).toList();
  }
//
  /// Get completed tasks for a specific section
  static Future<List<ToDoItem>> getCompletedTasksForSection(
    String sectionId,
  ) async {
    final allTasks = await loadTasks();
    return allTasks
        .where((task) => task.sectionId == sectionId && task.isCompleted)
        .toList();
  }

  /// Get incomplete (todo) tasks for a specific section
  static Future<List<ToDoItem>> getTodoTasksForSection(String sectionId) async {
    final allTasks = await loadTasks();
    return allTasks
        .where((task) => task.sectionId == sectionId && !task.isCompleted)
        .toList();
  }

  /// Create or update a project-linked section
  static Future<bool> createOrUpdateProjectSection({
    required String projectId,
    required String projectTitle,
  }) async {
    if (userId == null) {
      log("TasksAdapter.createOrUpdateProjectSection: No user ID available");
      return false;
    }

    try {
      // Check if project section already exists
      final existingSection = await getProjectSection(projectId);

      if (existingSection != null) {
        // Update last interacted time
        final updatedSection = existingSection.copyWith(
          lastInteracted: DateTime.now(),
          name: projectTitle, // Update name in case project was renamed
        );

        return await MongoDatabase.updateDataByQuery(
          {'id': existingSection.id, 'type': 'task_section'},
          updatedSection.toMap(),
          userId: userId,
        );
      } else {
        // Create new project section
        final sectionId = DateTime.now().millisecondsSinceEpoch.toString();
        final newSection = TaskSection(
          id: sectionId,
          name: projectTitle,
          isCompleted: false,
          projectId: projectId,
          lastInteracted: DateTime.now(),
          type: SectionType.projectLinked,
        );

        return await MongoDatabase.insertData(
          newSection.toMap(),
          userId: userId,
          type: 'task_section',
        );
      }
    } catch (e) {
      log("TasksAdapter.createOrUpdateProjectSection: Error: $e");
      return false;
    }
  }

  /// Get project section by project ID
  static Future<TaskSection?> getProjectSection(String projectId) async {
    if (userId == null) return null;

    try {
      final docs = await MongoDatabase.getData(
        userId: userId,
        type: 'task_section',
      );

      final sections = docs.map((doc) => TaskSection.fromMap(doc)).toList();
      return sections.firstWhere(
        (section) => section.projectId == projectId,
        orElse: () => throw StateError('Not found'),
      );
    } catch (e) {
      return null;
    }
  }

  /// Sync project tasks to task section
  static Future<bool> syncProjectTasks({
    required String projectId,
    required List<Map<String, dynamic>> projectTasks,
  }) async {
    if (userId == null) return false;

    try {
      final projectSection = await getProjectSection(projectId);
      if (projectSection == null) return false;

      // Delete existing tasks for this project
      await MongoDatabase.deleteDataByQuery({
        'sectionId': projectSection.id,
        'type': 'task_item',
      }, userId: userId);

      // Insert new tasks
      for (final taskData in projectTasks) {
        final task = ToDoItem(
          id:
              taskData['id'] ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          sectionId: projectSection.id,
          projectId: projectId,
          text: taskData['text'] ?? '',
          deadlineDate:
              taskData['deadlineDate'] is DateTime
                  ? taskData['deadlineDate']
                  : DateTime.parse(
                    taskData['deadlineDate'] ??
                        DateTime.now().toIso8601String(),
                  ),
          isCompleted: taskData['isCompleted'] ?? false,
          completedAt:
              taskData['completedAt'] != null
                  ? (taskData['completedAt'] is DateTime
                      ? taskData['completedAt']
                      : DateTime.parse(taskData['completedAt']))
                  : null,
        );

        await MongoDatabase.insertData(
          task.toMap(),
          userId: userId,
          type: 'task_item',
        );
      }

      // Update section last interacted time
      await MongoDatabase.updateDataByQuery(
        {'id': projectSection.id, 'type': 'task_section'},
        {'lastInteracted': DateTime.now().toIso8601String()},
        userId: userId,
      );

      return true;
    } catch (e) {
      log("TasksAdapter.syncProjectTasks: Error: $e");
      return false;
    }
  }

  /// Delete project section when project is deleted
  static Future<bool> deleteProjectSection(String projectId) async {
    if (userId == null) return false;

    try {
      final projectSection = await getProjectSection(projectId);
      if (projectSection == null) return true; // Already doesn't exist

      return await deleteSection(projectSection.id);
    } catch (e) {
      log("TasksAdapter.deleteProjectSection: Error: $e");
      return false;
    }
  }

  /// Update section interaction time
  static Future<bool> updateSectionInteraction(String sectionId) async {
    if (userId == null) return false;

    try {
      return await MongoDatabase.updateDataByQuery(
        {'id': sectionId, 'type': 'task_section'},
        {'lastInteracted': DateTime.now().toIso8601String()},
        userId: userId,
      );
    } catch (e) {
      log("TasksAdapter.updateSectionInteraction: Error: $e");
      return false;
    }
  }
}
