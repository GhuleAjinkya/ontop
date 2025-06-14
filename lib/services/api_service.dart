import 'dart:convert';
import 'package:http/http.dart' as http;
import '../user_session.dart';

class ApiService {
  // Base URL for your Node.js server - change to your actual server URL
  static const String baseUrl =
      'http://192.168.1.100:3000'; // Replace with your server's IP

  // Get auth token from user session (if needed)
  static Future<String?> _getAuthToken() async {
    final user = UserSession().currentUser;
    return user?['_id'];
  }

  // Generic GET request
  static Future<dynamic> get(String endpoint) async {
    final String? userId = await _getAuthToken();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userId',
        },
      );

      return _processResponse(response);
    } catch (e) {
      print('ApiService GET error: $e');
      throw Exception('Network error occurred');
    }
  }

  // Generic POST request
  static Future<dynamic> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final String? userId = await _getAuthToken();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userId',
        },
        body: json.encode(data),
      );

      return _processResponse(response);
    } catch (e) {
      print('ApiService POST error: $e');
      throw Exception('Network error occurred');
    }
  }

  // Generic PUT request
  static Future<dynamic> put(String endpoint, Map<String, dynamic> data) async {
    final String? userId = await _getAuthToken();

    try {
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userId',
        },
        body: json.encode(data),
      );

      return _processResponse(response);
    } catch (e) {
      print('ApiService PUT error: $e');
      throw Exception('Network error occurred');
    }
  }

  // Generic DELETE request
  static Future<dynamic> delete(String endpoint) async {
    final String? userId = await _getAuthToken();

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userId',
        },
      );

      return _processResponse(response);
    } catch (e) {
      print('ApiService DELETE error: $e');
      throw Exception('Network error occurred');
    }
  }

  // Process HTTP response
  static dynamic _processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return json.decode(response.body);
    } else {
      print('ApiService error: ${response.statusCode} - ${response.body}');

      Map<String, dynamic> errorData = {};
      try {
        errorData = json.decode(response.body);
      } catch (e) {
        errorData = {'message': 'An unknown error occurred'};
      }

      throw Exception(errorData['message'] ?? 'Request failed');
    }
  }
}
