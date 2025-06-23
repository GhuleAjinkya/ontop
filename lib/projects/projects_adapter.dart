import 'dart:convert';
import '../shared/mongodb.dart';
import '../shared/user_session.dart';
import '../shared/node_js_api.dart';

// Projects adapter service that works with both Node.js API and direct MongoDB
class ProjectsAdapter {
  // Flag to enable/disable Node.js API (fallback to MongoDB if false or on error)
  static bool useNodeJsApi = true;

  // Get all projects for the current user
  static Future<List<Map<String, dynamic>>> getProjects() async {
    final userId = UserSession().userId;
    if (userId == null) return [];

    if (useNodeJsApi) {
      try {
        // Try Node.js API first
        final response = await NodeJsApi.get('/api/projects');

        if (response['success']) {
          return List<Map<String, dynamic>>.from(response['data']);
        }
      } catch (e) {
        print('Error fetching projects from Node.js API: $e');
        // Continue to MongoDB fallback
      }
    }

    // Fallback to MongoDB
    return await MongoDatabase.getContacts(userId: userId, type: 'project');
  }

  // Add a new project
  static Future<bool> addProject(Map<String, dynamic> projectData) async {
    final userId = UserSession().userId;
    if (userId == null) return false;

    // Ensure type and timestamp fields are present
    projectData['type'] = 'project';
    projectData['created_at'] = DateTime.now().toIso8601String();

    if (useNodeJsApi) {
      try {
        // Try Node.js API first
        final response = await NodeJsApi.post('/api/projects', projectData);
        if (response['success']) return true;
      } catch (e) {
        print('Error adding project via Node.js API: $e');
        // Continue to MongoDB fallback
      }
    }

    // Fallback to MongoDB
    return await MongoDatabase.insertData(
      projectData,
      userId: userId,
      type: 'project',
    );
  }

  // Update an existing project
  static Future<bool> updateProject(Map<String, dynamic> projectData) async {
    final userId = UserSession().userId;
    if (userId == null) return false;

    // Ensure project has the necessary type field
    projectData['type'] = 'project';

    if (useNodeJsApi) {
      try {
        // Try Node.js API first
        final projectId = projectData['_id'].toString();
        final response = await NodeJsApi.put(
          '/api/projects/$projectId',
          projectData,
        );
        if (response['success']) return true;
      } catch (e) {
        print('Error updating project via Node.js API: $e');
        // Continue to MongoDB fallback
      }
    }

    // Fallback to MongoDB
    return await MongoDatabase.updateData(
      projectData,
      userId: userId,
      type: 'project',
    );
  }

  // Delete a project
  static Future<bool> deleteProject(dynamic projectId) async {
    final userId = UserSession().userId;
    if (userId == null) return false;

    if (useNodeJsApi) {
      try {
        // Try Node.js API first
        final response = await NodeJsApi.delete(
          '/api/projects/${projectId.toString()}',
        );
        if (response['success']) return true;
      } catch (e) {
        print('Error deleting project via Node.js API: $e');
        // Continue to MongoDB fallback
      }
    }

    // Fallback to MongoDB
    return await MongoDatabase.deleteData(projectId, userId: userId);
  }

  // Add a collaborator to a project
  static Future<bool> addCollaborator(
    dynamic projectId,
    dynamic contactId,
  ) async {
    final userId = UserSession().userId;
    if (userId == null) return false;

    if (useNodeJsApi) {
      try {
        // Try Node.js API first
        final collaboratorData = {'collaborator_id': contactId.toString()};
        final response = await NodeJsApi.post(
          '/api/projects/${projectId.toString()}/collaborators',
          collaboratorData,
        );
        if (response['success']) return true;
      } catch (e) {
        print('Error adding collaborator via Node.js API: $e');
        // Continue to MongoDB fallback
      }
    }

    // Fallback to MongoDB - get current project and update collaborators array
    try {
      final projects = await MongoDatabase.getContacts(
        userId: userId,
        type: 'project',
      );

      final project = projects.firstWhere(
        (p) => p['_id'].toString() == projectId.toString(),
      );

      final currentCollaborators = List<dynamic>.from(
        project['collaborators'] ?? [],
      );

      // Check if collaborator already exists
      if (!currentCollaborators.any(
        (id) => id.toString() == contactId.toString(),
      )) {
        currentCollaborators.add(contactId);

        final updatedProject = Map<String, dynamic>.from(project);
        updatedProject['collaborators'] = currentCollaborators;

        return await MongoDatabase.updateData(
          updatedProject,
          userId: userId,
          type: 'project',
        );
      }
      return true; // Already exists
    } catch (e) {
      print('Error adding collaborator to project in MongoDB: $e');
      return false;
    }
  }

  // Remove a collaborator from a project
  static Future<bool> removeCollaborator(
    dynamic projectId,
    dynamic contactId,
  ) async {
    final userId = UserSession().userId;
    if (userId == null) return false;

    if (useNodeJsApi) {
      try {
        // Try Node.js API first
        final response = await NodeJsApi.delete(
          '/api/projects/${projectId.toString()}/collaborators/${contactId.toString()}',
        );
        if (response['success']) return true;
      } catch (e) {
        print('Error removing collaborator via Node.js API: $e');
        // Continue to MongoDB fallback
      }
    }

    // Fallback to MongoDB - get current project and update collaborators array
    try {
      final projects = await MongoDatabase.getContacts(
        userId: userId,
        type: 'project',
      );

      final project = projects.firstWhere(
        (p) => p['_id'].toString() == projectId.toString(),
      );

      final currentCollaborators = List<dynamic>.from(
        project['collaborators'] ?? [],
      );

      // Remove the collaborator
      currentCollaborators.removeWhere(
        (id) => id.toString() == contactId.toString(),
      );

      final updatedProject = Map<String, dynamic>.from(project);
      updatedProject['collaborators'] = currentCollaborators;

      return await MongoDatabase.updateData(
        updatedProject,
        userId: userId,
        type: 'project',
      );
    } catch (e) {
      print('Error removing collaborator from project in MongoDB: $e');
      return false;
    }
  }

  // Get contacts that are collaborators for a specific project
  static Future<List<Map<String, dynamic>>> getProjectCollaborators(
    dynamic projectId,
  ) async {
    final userId = UserSession().userId;
    if (userId == null) return [];

    try {
      // Get the project
      final projects = await MongoDatabase.getContacts(
        userId: userId,
        type: 'project',
      );

      final project = projects.firstWhere(
        (p) => p['_id'].toString() == projectId.toString(),
      );

      final collaboratorIds = List<dynamic>.from(
        project['collaborators'] ?? [],
      );

      // Get all contacts
      final contacts = await MongoDatabase.getContacts(
        userId: userId,
        type: 'contact',
      );

      // Filter contacts that are collaborators
      return contacts.where((contact) {
        return collaboratorIds.any(
          (id) => id.toString() == contact['_id'].toString(),
        );
      }).toList();
    } catch (e) {
      print('Error getting project collaborators: $e');
      return [];
    }
  }

  // Export projects as JSON string
  static Future<String?> exportProjectsAsJson() async {
    final projects = await getProjects();
    if (projects.isEmpty) return null;

    return jsonEncode(projects);
  }

  // Import multiple projects
  static Future<bool> importProjects(
    List<Map<String, dynamic>> projects,
  ) async {
    final userId = UserSession().userId;
    if (userId == null) return false;

    // Ensure all projects have type field
    for (var project in projects) {
      project['type'] = 'project';
    }

    if (useNodeJsApi) {
      try {
        // Try Node.js API first
        final importData = {'projects': projects};
        final response = await NodeJsApi.post(
          '/api/projects/import',
          importData,
        );
        if (response['success']) return true;
      } catch (e) {
        print('Error importing projects via Node.js API: $e');
        // Continue to MongoDB fallback
      }
    }

    // Fallback to MongoDB
    return await MongoDatabase.insertMany(
      projects,
      userId: userId,
      type: 'project',
    );
  }
}
