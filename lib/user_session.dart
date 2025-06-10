import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// User Session Manager to handle user authentication state throughout the app
class UserSession {
  static final UserSession _instance = UserSession._internal();

  // Singleton pattern
  factory UserSession() {
    return _instance;
  }

  UserSession._internal();

  // Current user data
  Map<String, dynamic>? _currentUser;

  // Getters
  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  String? get userId => _currentUser?['_id']?.toString();
  String? get userName => _currentUser?['name'];
  // Initialize user session
  Future<bool> initialize() async {
    print('🔄 UserSession: Starting initialization...');
    try {
      final prefs = await SharedPreferences.getInstance();
      print('✅ UserSession: SharedPreferences instance obtained');

      final userJson = prefs.getString('user_data');
      print(
        '📄 UserSession: Retrieved user_data from storage: ${userJson != null ? "Data found" : "No data found"}',
      );      if (userJson != null) {
        print('🔍 UserSession: Parsing JSON data...');
        final Map<String, dynamic> userData = json.decode(userJson);
        
        // Convert string DateTime fields back to DateTime objects if needed
        if (userData['created_at'] is String) {
          try {
            userData['created_at'] = DateTime.parse(userData['created_at']);
            print('🔄 UserSession: Converted created_at back to DateTime');
          } catch (e) {
            print('⚠️ UserSession: Could not parse created_at as DateTime: $e');
          }
        }
        
        _currentUser = userData;
        print('✅ UserSession: User data parsed successfully');
        print('👤 UserSession: User ID: ${_currentUser?['_id']}');
        print('👤 UserSession: User Name: ${_currentUser?['name']}');
        print('✅ UserSession: Session initialized with user data');
        return true;
      } else {
        print('❌ UserSession: No saved user data found');
        return false;
      }
    } catch (e) {
      print('❌ UserSession: Error initializing user session: $e');
      return false;
    }
  }
  // Set current user and save to SharedPreferences
  Future<void> setUser(Map<String, dynamic> userData) async {
    print('💾 UserSession: Setting user data...');
    print('📝 UserSession: User data to save: ${userData.toString()}');

    _currentUser = userData;

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Convert DateTime objects to strings for JSON serialization
      final Map<String, dynamic> serializableData = Map<String, dynamic>.from(userData);
      serializableData.forEach((key, value) {
        if (value is DateTime) {
          serializableData[key] = value.toIso8601String();
          print('🔄 UserSession: Converted DateTime field "$key" to string');
        }
      });
      
      final userJsonString = json.encode(serializableData);
      await prefs.setString('user_data', userJsonString);

      print('✅ UserSession: User data saved successfully');
      print('📄 UserSession: Saved JSON: $userJsonString');

      // Verify the save worked
      final savedData = prefs.getString('user_data');
      print(
        '🔍 UserSession: Verification - retrieved data: ${savedData != null ? "Success" : "Failed"}',
      );
    } catch (e) {
      print('❌ UserSession: Error saving user data: $e');
    }
  }

  // Clear user session on logout
  Future<void> clearSession() async {
    print('🗑️ UserSession: Clearing user session...');
    _currentUser = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_data');
      print('✅ UserSession: Session cleared successfully');
    } catch (e) {
      print('❌ UserSession: Error clearing user session: $e');
    }
  }
}

// Global instance for easy access
final userSession = UserSession();
