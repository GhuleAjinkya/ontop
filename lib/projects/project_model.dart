import '../tasks/to_do_item_model.dart';

class Project {
  final dynamic id; // Can be ObjectId or its string representation
  String title;
  String description;
  List<dynamic> collaborators; // List of Contact ObjectIds
  List<ToDoItem> projectTasks;
  List<String>? completedTasks; // List of completed task IDs
  DateTime? createdAt;
  DateTime? lastInteracted; // For sorting recently interacted projects
  DateTime? completedAt; // When the project was completed
  bool isCompleted; // For greying out completed projects
  String? lastCompletedTask; // Store the last completed task text
  List<String>? completedTasksHistory; // History of completed tasks for undo
  DateTime? lastCrossedOff; // When the last task was crossed off
  Project({
    required this.id,
    required this.title,
    required this.description,
    required this.collaborators,
    required this.projectTasks,
    this.completedTasks,
    this.createdAt,
    this.lastInteracted,
    this.completedAt,
    this.isCompleted = false,
    this.lastCompletedTask,
    this.completedTasksHistory,
  }); // Convert MongoDB document to Project object
  factory Project.fromMongo(Map<String, dynamic> doc) {
    return Project(
      id: doc['_id'], // Keep as ObjectId
      title: doc['title'] ?? '',
      description: doc['description'] ?? '',
      collaborators: List<dynamic>.from(doc['collaborators'] ?? []),
      projectTasks:
          (doc['project_tasks'] as List<dynamic>? ?? [])
              .map((taskData) => ToDoItem.fromMap(taskData))
              .toList(),
      completedTasks:
          doc['completed_tasks'] != null
              ? List<String>.from(doc['completed_tasks'])
              : null,
      createdAt:
          doc['created_at'] != null ? DateTime.parse(doc['created_at']) : null,
      lastInteracted:
          doc['last_interacted'] != null
              ? DateTime.parse(doc['last_interacted'])
              : null,
      completedAt:
          doc['completed_at'] != null
              ? DateTime.parse(doc['completed_at'])
              : null,
      isCompleted: doc['is_completed'] ?? false,
      lastCompletedTask: doc['last_completed_task'],
      completedTasksHistory:
          doc['completed_tasks_history'] != null
              ? List<String>.from(doc['completed_tasks_history'])
              : null,
    );
  } // Convert Project to Map for MongoDB
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'collaborators': collaborators,
      'project_tasks': projectTasks.map((task) => task.toMap()).toList(),
      'completed_tasks': completedTasks,
      'type': 'project', // Add type field for database consistency
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      'last_interacted': lastInteracted?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'is_completed': isCompleted,
      'last_completed_task': lastCompletedTask,
      'completed_tasks_history': completedTasksHistory,
    };
  } // Create a copy of Project with updated values

  Project copyWith({
    dynamic id,
    String? title,
    String? description,
    List<dynamic>? collaborators,
    List<ToDoItem>? projectTasks,
    List<String>? completedTasks,
    DateTime? createdAt,
    DateTime? lastInteracted,
    DateTime? completedAt,
    bool? isCompleted,
    String? lastCompletedTask,
    List<String>? completedTasksHistory,
  }) {
    return Project(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      collaborators: collaborators ?? this.collaborators,
      projectTasks: projectTasks ?? this.projectTasks,
      completedTasks: completedTasks ?? this.completedTasks,
      createdAt: createdAt ?? this.createdAt,
      lastInteracted: lastInteracted ?? this.lastInteracted,
      completedAt: completedAt ?? this.completedAt,
      isCompleted: isCompleted ?? this.isCompleted,
      lastCompletedTask: lastCompletedTask ?? this.lastCompletedTask,
      completedTasksHistory:
          completedTasksHistory ?? this.completedTasksHistory,
    );
  }
}
