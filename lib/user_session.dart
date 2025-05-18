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
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user_data');
      
      if (userJson != null) {
        _currentUser = json.decode(userJson);
        return true;
      }
      return false;
    } catch (e) {
      print('Error initializing user session: $e');
      return false;
    }
  }
  
  // Set current user and save to SharedPreferences
  Future<void> setUser(Map<String, dynamic> userData) async {
    _currentUser = userData;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', json.encode(userData));
    } catch (e) {
      print('Error saving user data: $e');
    }
  }
  
  // Clear user session on logout
  Future<void> clearSession() async {
    _currentUser = null;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_data');
    } catch (e) {
      print('Error clearing user session: $e');
    }
  }
}

// Global instance for easy access
final userSession = UserSession();
