import 'dart:convert';
import 'package:http/http.dart' as http;
import 'user_session.dart';

// Node.js API connection helper
class NodeJsApi {
  // Base URL for your Node.js server - change to your actual server URL
  static const String baseUrl =
      'http://localhost:3000'; // Update with your actual Node.js server URL

  // Get auth token from user session
  static String? _getAuthToken() {
    return UserSession().userId;
  }

  // Generic GET request with error handling and fallback capability
  static Future<Map<String, dynamic>> get(String endpoint) async {
    final String? userId = _getAuthToken();
    if (userId == null) {
      return {'success': false, 'error': 'No user ID available'};
    }

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl$endpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $userId',
            },
          )
          .timeout(const Duration(seconds: 10)); // Add timeout

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'success': true,
          'data': json.decode(response.body),
          'statusCode': response.statusCode,
        };
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print('NodeJsApi GET error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Generic POST request with error handling
  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final String? userId = _getAuthToken();
    if (userId == null) {
      return {'success': false, 'error': 'No user ID available'};
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $userId',
            },
            body: json.encode(data),
          )
          .timeout(const Duration(seconds: 10)); // Add timeout

      if (response.statusCode >= 200 && response.statusCode < 300) {
        var responseData =
            response.body.isEmpty ? {} : json.decode(response.body);
        return {
          'success': true,
          'data': responseData,
          'statusCode': response.statusCode,
        };
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print('NodeJsApi POST error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Generic PUT request with error handling
  static Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final String? userId = _getAuthToken();
    if (userId == null) {
      return {'success': false, 'error': 'No user ID available'};
    }

    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl$endpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $userId',
            },
            body: json.encode(data),
          )
          .timeout(const Duration(seconds: 10)); // Add timeout

      if (response.statusCode >= 200 && response.statusCode < 300) {
        var responseData =
            response.body.isEmpty ? {} : json.decode(response.body);
        return {
          'success': true,
          'data': responseData,
          'statusCode': response.statusCode,
        };
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print('NodeJsApi PUT error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Generic DELETE request with error handling
  static Future<Map<String, dynamic>> delete(String endpoint) async {
    final String? userId = _getAuthToken();
    if (userId == null) {
      return {'success': false, 'error': 'No user ID available'};
    }

    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl$endpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $userId',
            },
          )
          .timeout(const Duration(seconds: 10)); // Add timeout

      if (response.statusCode >= 200 && response.statusCode < 300) {
        var responseData =
            response.body.isEmpty ? {} : json.decode(response.body);
        return {
          'success': true,
          'data': responseData,
          'statusCode': response.statusCode,
        };
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print('NodeJsApi DELETE error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
