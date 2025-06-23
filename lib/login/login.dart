import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../home/main.dart';
import '../shared/mongodb.dart';
import 'dart:async';
import '../shared/user_session.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController phoneNumber = TextEditingController();
  final TextEditingController password = TextEditingController();
  final TextEditingController confirmPassword = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController name = TextEditingController();

  bool loggingIn = true;
  bool isLoading = false;
  String errorMessage = '';
  bool showPassword = false;
  bool showConfirmPassword = false;

  // Form validation key
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    // Clean up the controllers when the widget is disposed
    phoneNumber.dispose();
    password.dispose();
    confirmPassword.dispose();
    email.dispose();
    name.dispose();
    super.dispose();
  }

  // Method to validate email format
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  // Method to validate login form
  bool _validateLoginForm() {
    if (phoneNumber.text.isEmpty) {
      setState(() => errorMessage = 'Phone number is required');
      return false;
    }

    if (password.text.isEmpty) {
      setState(() => errorMessage = 'Password is required');
      return false;
    }

    return true;
  }

  // Method to validate signup form
  bool _validateSignupForm() {
    if (name.text.isEmpty) {
      setState(() => errorMessage = 'Full name is required');
      return false;
    }

    if (phoneNumber.text.isEmpty) {
      setState(() => errorMessage = 'Phone number is required');
      return false;
    }

    if (email.text.isEmpty) {
      setState(() => errorMessage = 'Email is required');
      return false;
    }

    if (!_isValidEmail(email.text)) {
      setState(() => errorMessage = 'Please enter a valid email');
      return false;
    }

    if (password.text.isEmpty) {
      setState(() => errorMessage = 'Password is required');
      return false;
    }

    if (password.text != confirmPassword.text) {
      setState(() => errorMessage = 'Passwords do not match');
      return false;
    }

    return true;
  }

  // Method to handle login
  Future<void> _handleLogin() async {
    if (!_validateLoginForm()) return;
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      var result = await MongoDatabase.loginUser(
        phoneNumber: phoneNumber.text,
        password: password.text,
      );
      if (result['success']) {
        print('🎉 Login: Login successful, user data: ${result['user']}');

        // Save user data to session
        print('💾 Login: Saving user data to session...');
        await userSession.setUser(result['user']);
        print(
          '✅ Login: User data saved, session status: ${userSession.isLoggedIn}',
        );

        // Navigate to home page on successful login with user data
        if (mounted) {
          print('🏠 Login: Navigating to home page...');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomePage(userData: result['user']),
            ),
          );
        }
      } else {
        setState(() => errorMessage = result['message']);
      }
    } catch (e) {
      setState(() => errorMessage = 'An error occurred. Please try again.');
      print('Login error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Method to handle signup
  Future<void> _handleSignup() async {
    if (!_validateSignupForm()) return;

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      // Prepare user data
      Map<String, dynamic> userData = {
        'name': name.text,
        'email': email.text,
        'number': phoneNumber.text,
        'password': password.text,
        'confirm_password': confirmPassword.text,
      };

      var result = await MongoDatabase.registerUser(userData);

      if (result['success']) {
        // Switch to login mode after successful registration
        setState(() {
          loggingIn = true;
          phoneNumber.text =
              userData['number']; // Pre-fill phone for convenience
          password.clear();
          errorMessage = 'Registration successful! Please log in.';
        });
      } else {
        setState(() => errorMessage = result['message']);
      }
    } catch (e) {
      setState(() => errorMessage = 'An error occurred during registration.');
      print('Registration error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: IntrinsicHeight(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Spacer(flex: 1),
                        Container(
                          alignment: Alignment.center,
                          child: Text(
                            "ontop.",
                            style: TextStyle(
                              fontSize: 45,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: 20),

                        // Display error message if any
                        if (errorMessage.isNotEmpty)
                          Container(
                            width: double.infinity,
                            margin: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color:
                                  errorMessage.contains('successful')
                                      ? Colors.green.withValues(alpha: 0.2)
                                      : Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color:
                                    errorMessage.contains('successful')
                                        ? Colors.green
                                        : Colors.red,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              errorMessage,
                              style: TextStyle(
                                color:
                                    errorMessage.contains('successful')
                                        ? Colors.green[200]
                                        : Colors.red[200],
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        SizedBox(
                          height: loggingIn ? 200 : 340,
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 20),
                            child:
                                loggingIn
                                    ?
                                    // Login Form
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        TextField(
                                          controller: phoneNumber,
                                          keyboardType:
                                              TextInputType.numberWithOptions(
                                                signed: false,
                                                decimal: false,
                                              ),
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          style: TextStyle(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onPrimary,
                                          ),
                                          cursorColor:
                                              Theme.of(
                                                context,
                                              ).colorScheme.tertiary,
                                          decoration: InputDecoration(
                                            hintText: 'Phone Number',
                                            labelText: 'Phone Number',
                                            prefixIcon: Icon(
                                              Icons.phone_android,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onSecondary,
                                            ),
                                            labelStyle: TextStyle(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onSecondary,
                                            ),
                                            hintStyle: TextStyle(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onSecondary,
                                            ),
                                            border:
                                                const UnderlineInputBorder(),
                                          ),
                                        ),
                                        SizedBox(height: 15),
                                        TextField(
                                          controller: password,
                                          obscureText: !showPassword,
                                          style: TextStyle(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onPrimary,
                                          ),
                                          cursorColor:
                                              Theme.of(
                                                context,
                                              ).colorScheme.tertiary,
                                          decoration: InputDecoration(
                                            hintText: 'Password',
                                            labelText: 'Password',
                                            prefixIcon: Icon(
                                              Icons.lock_outline,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onSecondary,
                                            ),
                                            suffixIcon: IconButton(
                                              icon: Icon(
                                                showPassword
                                                    ? Icons.visibility_off
                                                    : Icons.visibility,
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.onSecondary,
                                              ),
                                              onPressed: () {
                                                setState(
                                                  () =>
                                                      showPassword =
                                                          !showPassword,
                                                );
                                              },
                                            ),
                                            labelStyle: TextStyle(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onSecondary,
                                            ),
                                            hintStyle: TextStyle(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onSecondary,
                                            ),
                                            border:
                                                const UnderlineInputBorder(),
                                          ),
                                        ),
                                      ],
                                    )
                                    :
                                    // Registration/Signup Form
                                    ListView(
                                      padding: EdgeInsets.zero,
                                      children: [
                                        TextField(
                                          controller: name,
                                          style: TextStyle(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onPrimary,
                                          ),
                                          cursorColor:
                                              Theme.of(
                                                context,
                                              ).colorScheme.tertiary,
                                          decoration: InputDecoration(
                                            hintText: 'Full Name',
                                            labelText: 'Full Name',
                                            prefixIcon: Icon(
                                              Icons.person_outline,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onSecondary,
                                            ),
                                            labelStyle: TextStyle(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onSecondary,
                                            ),
                                            hintStyle: TextStyle(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onSecondary,
                                            ),
                                            border:
                                                const UnderlineInputBorder(),
                                          ),
                                        ),
                                        SizedBox(height: 15),
                                        TextField(
                                          controller: phoneNumber,
                                          keyboardType:
                                              TextInputType.numberWithOptions(
                                                signed: false,
                                                decimal: false,
                                              ),
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          style: TextStyle(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onPrimary,
                                          ),
                                          cursorColor:
                                              Theme.of(
                                                context,
                                              ).colorScheme.tertiary,
                                          decoration: InputDecoration(
                                            hintText: 'Phone Number',
                                            labelText: 'Phone Number',
                                            prefixIcon: Icon(
                                              Icons.phone_android,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onSecondary,
                                            ),
                                            labelStyle: TextStyle(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onSecondary,
                                            ),
                                            hintStyle: TextStyle(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onSecondary,
                                            ),
                                            border:
                                                const UnderlineInputBorder(),
                                          ),
                                        ),
                                        SizedBox(height: 15),
                                        TextField(
                                          controller: email,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          style: TextStyle(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onPrimary,
                                          ),
                                          cursorColor:
                                              Theme.of(
                                                context,
                                              ).colorScheme.tertiary,
                                          decoration: InputDecoration(
                                            hintText: 'E-mail ID',
                                            labelText: 'E-mail ID',
                                            prefixIcon: Icon(
                                              Icons.email_outlined,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onSecondary,
                                            ),
                                            labelStyle: TextStyle(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onSecondary,
                                            ),
                                            hintStyle: TextStyle(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onSecondary,
                                            ),
                                            border:
                                                const UnderlineInputBorder(),
                                          ),
                                        ),
                                        SizedBox(height: 15),
                                        TextField(
                                          controller: password,
                                          obscureText: !showPassword,
                                          style: TextStyle(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onPrimary,
                                          ),
                                          cursorColor:
                                              Theme.of(
                                                context,
                                              ).colorScheme.tertiary,
                                          decoration: InputDecoration(
                                            hintText: 'Password',
                                            labelText: 'Password',
                                            prefixIcon: Icon(
                                              Icons.lock_outline,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onSecondary,
                                            ),
                                            suffixIcon: IconButton(
                                              icon: Icon(
                                                showPassword
                                                    ? Icons.visibility_off
                                                    : Icons.visibility,
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.onSecondary,
                                              ),
                                              onPressed: () {
                                                setState(
                                                  () =>
                                                      showPassword =
                                                          !showPassword,
                                                );
                                              },
                                            ),
                                            labelStyle: TextStyle(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onSecondary,
                                            ),
                                            hintStyle: TextStyle(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onSecondary,
                                            ),
                                            border:
                                                const UnderlineInputBorder(),
                                          ),
                                        ),
                                        SizedBox(height: 15),
                                        TextField(
                                          controller: confirmPassword,
                                          obscureText: !showConfirmPassword,
                                          style: TextStyle(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onPrimary,
                                          ),
                                          cursorColor:
                                              Theme.of(
                                                context,
                                              ).colorScheme.tertiary,
                                          decoration: InputDecoration(
                                            hintText: 'Confirm Password',
                                            labelText: 'Confirm Password',
                                            prefixIcon: Icon(
                                              Icons.lock_outline,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onSecondary,
                                            ),
                                            suffixIcon: IconButton(
                                              icon: Icon(
                                                showConfirmPassword
                                                    ? Icons.visibility_off
                                                    : Icons.visibility,
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.onSecondary,
                                              ),
                                              onPressed: () {
                                                setState(
                                                  () =>
                                                      showConfirmPassword =
                                                          !showConfirmPassword,
                                                );
                                              },
                                            ),
                                            labelStyle: TextStyle(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onSecondary,
                                            ),
                                            hintStyle: TextStyle(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onSecondary,
                                            ),
                                            border:
                                                const UnderlineInputBorder(),
                                          ),
                                        ),
                                      ],
                                    ),
                          ),
                        ), // Login/Signup Button
                        Container(
                          margin: EdgeInsets.only(top: 25),
                          decoration: standardTile(20),
                          child: Container(
                            margin: EdgeInsets.all(3),
                            width: MediaQuery.of(context).size.width * 0.8,
                            height: 50,
                            child:
                                isLoading
                                    ? Center(
                                      child: CircularProgressIndicator(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onPrimary,
                                        strokeWidth: 3,
                                      ),
                                    )
                                    : TextButton(
                                      onPressed: () {
                                        // Hide keyboard when button is pressed
                                        FocusScope.of(context).unfocus();

                                        if (loggingIn) {
                                          _handleLogin();
                                        } else {
                                          _handleSignup();
                                        }
                                      },
                                      child: Text(
                                        loggingIn ? "Log In" : "Sign Up",
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onPrimary,
                                        ),
                                      ),
                                    ),
                          ),
                        ),

                        // Toggle between Login and Signup
                        Container(
                          margin: EdgeInsets.only(top: 20, bottom: 20),
                          child: TextButton(
                            onPressed: () {
                              if (isLoading) {
                                return; // Prevent switching while loading
                              }

                              setState(() {
                                loggingIn = !loggingIn;
                                errorMessage = ''; // Clear any error messages
                              });

                              // Clear fields when switching forms
                              if (loggingIn) {
                                phoneNumber.clear();
                                password.clear();
                              } else {
                                name.clear();
                                phoneNumber.clear();
                                email.clear();
                                password.clear();
                                confirmPassword.clear();
                              }
                            },
                            child: Text.rich(
                              TextSpan(
                                text:
                                    loggingIn
                                        ? "Don't have an account? "
                                        : "Already have an account? ",
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSecondary,
                                  fontWeight: FontWeight.normal,
                                ),
                                children: [
                                  TextSpan(
                                    text: loggingIn ? "Sign Up" : "Log In",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Spacer(flex: 1),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
