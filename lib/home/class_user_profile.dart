import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../shared/user_session.dart';
import '../login/login.dart';
// ignore: unused_import
import '../notifications/call_notifs/call_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../shared/mongodb.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../shared/dialog_helper.dart'; // Add dialog helper!


class UserProfile extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const UserProfile({super.key, this.userData});

  @override
  State<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  bool _notificationsEnabled = true;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNotificationPreference();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadNotificationPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    });
  }

  Future<void> _saveNotificationPreference(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: BorderSide(
                color: Theme.of(context).colorScheme.onSecondary,
                width: 1.5,
              ),
            ),
            title: Text(
              'Change Password',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _currentPasswordController,
                  obscureText: true,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _newPasswordController,
                  obscureText: true,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
                      _currentPasswordController.clear();
                      _newPasswordController.clear();
                      _confirmPasswordController.clear();
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _handlePasswordChange,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    child: const Text('Change'),
                  ),
                ],
              ),
            ],
          ),
    );
  }

  Future<void> _handlePasswordChange() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showModernSnackBar('New passwords do not match', isError: true);
      return;
    }

    if (_newPasswordController.text.length < 6) {
      _showModernSnackBar(
        'Password must be at least 6 characters',
        isError: true,
      );
      return;
    }

    // Show loading indicator
    _showModernSnackBar('Updating password...');

    try {
      // Get current user data
      final userData = userSession.currentUser;
      if (userData == null) {
        _showModernSnackBar(
          'User session not found. Please log in again.',
          isError: true,
        );
        return;
      }

      // Verify current password by attempting login with current credentials
      final loginResult = await MongoDatabase.loginUser(
        phoneNumber: userData['number'],
        password: _currentPasswordController.text,
      );

      if (!loginResult['success']) {
        _showModernSnackBar('Current password is incorrect', isError: true);
        return;
      }

      // Hash the new password
      String newPasswordHash = _hashPassword(_newPasswordController.text);

      // Update password
      bool updateSuccess = await _updateUserPassword(
        userData['_id'],
        newPasswordHash,
      );

      if (updateSuccess) {
        _showModernSnackBar('Password changed successfully');

        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        Navigator.of(context).pop();
      } else {
        _showModernSnackBar(
          'Failed to update password. Please try again.',
          isError: true,
        );
      }
    } catch (e) {
      print('Error changing password: $e');
      _showModernSnackBar(
        'Error updating password. Please try again.',
        isError: true,
      );
    }
  }

  void _showModernSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError
                ? Colors.red.shade400
                : Theme.of(context).colorScheme.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<bool> _updateUserPassword(
    String userId,
    String newPasswordHash,
  ) async {
    try {
      // Use the new MongoDB method to update the user's password
      bool success = await MongoDatabase.updateUserPassword(
        userId,
        newPasswordHash,
      );

      if (success) {
        print('Password updated successfully for user $userId');
      } else {
        print('Failed to update password for user $userId');
      }

      return success;
    } catch (e) {
      print('Error updating user password: $e');
      return false;
    }
  }

  // Helper method to hash passwords (same as in MongoDatabase)
  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  void _handleLogout() async {
    // Use the consistent dialog helper for sign out confirmation! ✨
    DialogHelper.showSignOutConfirmation(
      context: context,
      onSignOut: () async {
        // Clear user session
        await userSession.clearSession();

        // Navigate to login page
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => LoginPage()),
            (route) => false,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userData = widget.userData ?? userSession.currentUser;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        title: Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 22,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // BIG BOLD central blob - the STAR! 🌟
            Positioned(
              left:
                  MediaQuery.of(context).size.width * 0.5 -
                  150, // Adjusted for bigger size
              top:
                  MediaQuery.of(context).size.height * 0.4 -
                  50, // Adjusted for bigger size
              child: Container(
                width: 300, // MUCH BIGGER!
                height: 300, // HUGE!
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.secondary.withValues(
                    alpha: 0.6, // Much more visible!
                  ),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 120,
                    sigmaY: 120,
                  ), // More dramatic blur
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            // Small accent blob ABOVE - cute little satellite! ✨
            Positioned(
              left: MediaQuery.of(context).size.width * 0.5 - 60,
              top:
                  MediaQuery.of(context).size.height *
                  0.15, // Above the main blob
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.secondary.withValues(
                    alpha: 0.4, // Lighter accent
                  ),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            // Small accent blob BELOW - another cute satellite! 💫
            Positioned(
              left: MediaQuery.of(context).size.width * 0.5 - 60,
              top:
                  MediaQuery.of(context).size.height *
                  0.7, // Below the main blob
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.secondary.withValues(
                    alpha: 0.4, // Lighter accent
                  ),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            // Main content
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),

                  // Modern Profile Header with Glassmorphism
                  _buildGlassmorphicCard(
                    child: Column(
                      children: [
                        // Animated Profile Avatar
                        Hero(
                          tag: 'profile-avatar',
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Theme.of(context).colorScheme.secondary,
                                  Theme.of(context).colorScheme.secondary
                                      .withValues(alpha: 0.7),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).colorScheme.secondary
                                      .withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.person_rounded,
                              size: 60,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // User Name with modern typography
                        Text(
                          userData?['name'] ?? 'Unknown User',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onPrimary,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Personal Information with Modern Cards
                  _buildGlassmorphicCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          'Your Details',
                          Icons.person_outline,
                        ),
                        const SizedBox(height: 20),
                        _buildModernInfoTile(
                          icon: Icons.person_outline,
                          label: 'Full Name',
                          value: userData?['name'] ?? 'Not provided',
                          gradient: [
                            Colors.deepPurple.withValues(alpha: 0.3),
                            Colors.deepPurple.withValues(alpha: 0.15),
                          ],
                        ),

                        const SizedBox(height: 16),

                        _buildModernInfoTile(
                          icon: Icons.phone_outlined,
                          label: 'Phone Number',
                          value: userData?['number'] ?? 'Not provided',
                          gradient: [
                            Colors.deepPurple.withValues(alpha: 0.3),
                            Colors.deepPurple.withValues(alpha: 0.15),
                          ],
                        ),

                        const SizedBox(height: 16),

                        _buildModernInfoTile(
                          icon: Icons.email_outlined,
                          label: 'Email Address',
                          value: userData?['email'] ?? 'Not provided',
                          gradient: [
                            Colors.deepPurple.withValues(alpha: 0.3),
                            Colors.deepPurple.withValues(alpha: 0.15),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Settings Section with Modern Toggle
                  _buildGlassmorphicCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          'Settings',
                          Icons.settings_outlined,
                        ),
                        const SizedBox(height: 20),

                        // Modern Notifications Toggle
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.white.withValues(alpha: 0.05),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.orange.withValues(alpha: 0.2),
                                      Colors.orange.withValues(alpha: 0.1),
                                    ],
                                  ),
                                ),
                                child: Icon(
                                  Icons.notifications_outlined,
                                  color: Colors.orange,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Call Notifications',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Receive notifications for incoming calls',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimary
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Transform.scale(
                                scale: 0.8,
                                child: Switch(
                                  value: _notificationsEnabled,
                                  onChanged: (value) async {
                                    HapticFeedback.lightImpact();
                                    setState(() {
                                      _notificationsEnabled = value;
                                    });
                                    await _saveNotificationPreference(value);

                                    await CallNotificationService().reloadNotificationPreference();

                                    _showModernSnackBar(
                                      value
                                          ? 'Call notifications enabled'
                                          : 'Call notifications disabled',
                                    );
                                  },
                                  activeColor:
                                      Theme.of(context)
                                          .colorScheme
                                          .tertiary, // Beautiful lilac accent!
                                  activeTrackColor: Theme.of(context)
                                      .colorScheme
                                      .tertiary // Lilac accent track too!
                                      .withValues(alpha: 0.3),
                                  inactiveThumbColor: Colors.white.withValues(
                                    alpha: 0.8,
                                  ),
                                  inactiveTrackColor: Colors.white.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Modern Change Password Button
                        _buildModernActionButton(
                          onPressed: _showChangePasswordDialog,
                          icon: Icons.lock_outline,
                          label: 'Change Password',
                          gradient: [
                            Theme.of(context).colorScheme.secondary,
                            Theme.of(
                              context,
                            ).colorScheme.secondary.withValues(alpha: 0.8),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Modern Logout Button
                  _buildModernActionButton(
                    onPressed: _handleLogout,
                    icon: Icons.logout_rounded,
                    label: 'Sign Out',
                    gradient: [Colors.red.shade400, Colors.red.shade600],
                    isDestructive: true,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build glassmorphic cards
  Widget _buildGlassmorphicCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.white.withValues(alpha: 0.1),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  // Helper method to build section headers
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.white.withValues(alpha: 0.1),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onPrimary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // Helper method to build modern info tiles
  Widget _buildModernInfoTile({
    required IconData icon,
    required String label,
    required String value,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(colors: gradient),
            ),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withValues(alpha: 0.7),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build modern action buttons
  Widget _buildModernActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required List<Color> gradient,
    bool isDestructive = false,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.3),
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.mediumImpact();
            onPressed();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
