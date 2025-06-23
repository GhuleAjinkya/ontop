import 'dart:developer';
import 'tasks_adapter.dart' as tasks_adapter;
import '../projects/projects_adapter.dart';
import '../projects/project.dart';
import 'to_do_item.dart';

/// Service to sync project tasks with task sections
class ProjectTasksSync {
  /// Sync project tasks to Tasks tab when project tasks are modified
  static Future<bool> syncProjectToTasks(Project project) async { // doesnt work
    try {
      log("ProjectTasksSync: Syncing project ${project.title} to tasks");

      // Create or update project section
      await tasks_adapter.TasksAdapter.createOrUpdateProjectSection(
        projectId: project.id.toString(),
        projectTitle: project.title,
      );

      // Convert project tasks to task data format
      final taskDataList =
          project.projectTasks
              .map(
                (task) => {
                  'id': task.id,
                  'text': task.text,
                  'deadlineDate': task.deadlineDate,
                  'isCompleted':
                      project.completedTasks?.contains(task.id) ?? false,
                  'completedAt':
                      project.completedTasks?.contains(task.id) == true
                          ? DateTime.now() // Approximate since we don't track exact completion time in projects
                          : null,
                },
              )
              .toList();
      // Sync tasks
      final success = await tasks_adapter.TasksAdapter.syncProjectTasks(
        projectId: project.id.toString(),
        projectTasks: taskDataList,
      );

      if (success) {
        log("ProjectTasksSync: Successfully synced project ${project.title}");
      } else {
        log("ProjectTasksSync: Failed to sync project ${project.title}");
      }

      return success;
    } catch (e) {
      log("ProjectTasksSync: Error syncing project: $e");
      return false;
    }
  }

  /// Remove project section when project is deleted
  static Future<bool> removeProjectFromTasks(String projectId) async { //
    try {
      log("ProjectTasksSync: Removing project $projectId from tasks");

      final success = await tasks_adapter.TasksAdapter.deleteProjectSection(
        projectId,
      );

      if (success) {
        log("ProjectTasksSync: Successfully removed project $projectId");
      } else {
        log("ProjectTasksSync: Failed to remove project $projectId");
      }

      return success;
    } catch (e) {
      log("ProjectTasksSync: Error removing project: $e");
      return false;
    }
  }

  /// Sync task completion from Tasks tab back to project
  static Future<bool> syncTaskCompletionToProject({ // works
    required String taskId,
    required String projectId,
    required bool isCompleted,
  }) async {
    try {
      log(
        "ProjectTasksSync: Syncing task $taskId completion to project $projectId",
      );

      // Load the project to update its completion status
      final projectDocs = await ProjectsAdapter.getProjects();
      final projectDoc = projectDocs.firstWhere(
        (p) => p['_id'].toString() == projectId,
        orElse: () => throw Exception('Project not found'),
      );

      // Convert to Project object
      final project = Project.fromMongo(projectDoc);

      // Update the project's completed tasks
      List<String> completedTasks = List<String>.from(
        project.completedTasks ?? [],
      );
      List<String> completedTasksHistory = List<String>.from(
        project.completedTasksHistory ?? [],
      );

      if (isCompleted) {
        // Mark task as completed
        if (!completedTasks.contains(taskId)) {
          completedTasks.add(taskId);
          completedTasksHistory.remove(taskId); // Remove if already exists
          completedTasksHistory.add(taskId); // Add to end (most recent)
        }
      } else {
        // Mark task as incomplete
        completedTasks.remove(taskId);
        completedTasksHistory.remove(taskId);
      }

      // Update the project in database
      final updatedProject = project.copyWith(
        projectTasks: project.projectTasks,
      );
      final projectData = updatedProject.toMap();
      projectData['_id'] = updatedProject.id;
      projectData['completed_tasks'] = completedTasks;
      projectData['completed_tasks_history'] = completedTasksHistory;

      final success = await ProjectsAdapter.updateProject(projectData);

      if (success) {
        log(
          "ProjectTasksSync: Task $taskId in project $projectId marked as ${isCompleted ? 'completed' : 'incomplete'}",
        );
      } else {
        log("ProjectTasksSync: Failed to update project $projectId");
      }
      return success;
    } catch (e) {
      log("ProjectTasksSync: Error syncing task completion: $e");
      return false;
    }
  }

  /// Sync new task from Tasks tab back to project
  static Future<bool> syncTaskToProject({ // works
    required String projectId,
    required String taskText,
    required DateTime taskDeadline,
  }) async {
    try {
      log("ProjectTasksSync: Adding task '$taskText' to project $projectId");

      // Load the project to add the new task
      final projectDocs = await ProjectsAdapter.getProjects();
      final projectDoc = projectDocs.firstWhere(
        (p) => p['_id'].toString() == projectId,
        orElse: () => throw Exception('Project not found'),
      );

      // Convert to Project object
      final project = Project.fromMongo(projectDoc);

      // Create new task and add to project tasks
      final newTask = ToDoItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: taskText,
        deadlineDate: taskDeadline,
      );

      // Add the new task to project tasks
      final updatedProjectTasks = List<ToDoItem>.from(project.projectTasks)
        ..add(newTask);

      // Update the project in database
      final updatedProject = project.copyWith(
        projectTasks: updatedProjectTasks,
      );
      final projectData = updatedProject.toMap();
      projectData['_id'] = updatedProject.id;

      final success = await ProjectsAdapter.updateProject(projectData);

      if (success) {
        log("ProjectTasksSync: Task '$taskText' added to project $projectId");
      } else {
        log("ProjectTasksSync: Failed to add task to project $projectId");
      }

      return success;
    } catch (e) {
      log("ProjectTasksSync: Error syncing task to project: $e");
      return false;
    }
  }

  /// Sync task deletion from Tasks tab back to project
  static Future<bool> syncTaskDeletionToProject({ // works
    required String taskId,
    required String projectId,
  }) async {
    try {
      log("ProjectTasksSync: Deleting task $taskId from project $projectId");

      // Load the project to remove the task
      final projectDocs = await ProjectsAdapter.getProjects();
      final projectDoc = projectDocs.firstWhere(
        (p) => p['_id'].toString() == projectId,
        orElse: () => throw Exception('Project not found'),
      );

      // Convert to Project object
      final project = Project.fromMongo(projectDoc);

      // Remove the task from project tasks
      final updatedProjectTasks =
          project.projectTasks.where((task) => task.id != taskId).toList();

      // Also remove from completed tasks and history if present
      List<String> completedTasks = List<String>.from(
        project.completedTasks ?? [],
      );
      List<String> completedTasksHistory = List<String>.from(
        project.completedTasksHistory ?? [],
      );

      completedTasks.remove(taskId);
      completedTasksHistory.remove(taskId);

      // Update the project in database
      final updatedProject = project.copyWith(
        projectTasks: updatedProjectTasks,
      );
      final projectData = updatedProject.toMap();
      projectData['_id'] = updatedProject.id;
      projectData['completed_tasks'] = completedTasks;
      projectData['completed_tasks_history'] = completedTasksHistory;

      final success = await ProjectsAdapter.updateProject(projectData);

      if (success) {
        log("ProjectTasksSync: Task $taskId deleted from project $projectId");
      } else {
        log("ProjectTasksSync: Failed to delete task from project $projectId");
      }

      return success;
    } catch (e) {
      log("ProjectTasksSync: Error syncing task deletion: $e");
      return false;
    }
  }
}
