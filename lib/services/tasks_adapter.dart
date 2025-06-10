import 'dart:developer';
import '../mongodb.dart';
import '../user_session.dart';

class TaskSection {
  final String id;
  final String name;
  final bool isCompleted;

  TaskSection({
    required this.id,
    required this.name,
    required this.isCompleted,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isCompleted': isCompleted,
      'type': 'task_section',
    };
  }

  static TaskSection fromMap(Map<String, dynamic> map) {
    return TaskSection(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
    );
  }
}

class ToDoItem {
  final String id;
  final String sectionId;
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
    this.completedAt,
  });
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sectionId': sectionId,
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
    String? text,
    DateTime? deadlineDate,
    bool? isCompleted,
    DateTime? completedAt,
  }) {
    return ToDoItem(
      id: id ?? this.id,
      sectionId: sectionId ?? this.sectionId,
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
      final docs = await MongoDatabase.getContacts(
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
      final docs = await MongoDatabase.getContacts(
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
}
