import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main.dart';

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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Center(              
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.3,
                    child: Container(
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
                    )
                  ),
                  SizedBox(
                    height: 275,
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 20),
                      child: loggingIn ? 
                        Column(    
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextField(
                              controller: phoneNumber,
                              keyboardType: TextInputType.numberWithOptions(
                                signed: false,
                                decimal: false,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                              cursorColor: Theme.of(context).colorScheme.tertiary,
                              decoration: InputDecoration(
                                hintText: 'Phone Number',
                                labelText: 'Phone Number',
                                labelStyle: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSecondary,
                                ),
                                hintStyle: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSecondary,
                                ),
                                border: const UnderlineInputBorder(),
                              ),
                            ),
                            TextField(
                              controller: password,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                              cursorColor: Theme.of(context).colorScheme.tertiary,
                              decoration: InputDecoration(
                                hintText: 'Password',
                                labelText: 'Password',
                                labelStyle: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSecondary,
                                ),
                                hintStyle: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSecondary,
                                ),
                                border: const UnderlineInputBorder(),
                              ),
                            )
                          ],
                        ) : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextField(
                              controller: name,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                              cursorColor: Theme.of(context).colorScheme.tertiary,
                              decoration: InputDecoration(
                                hintText: 'Full Name',
                                labelText: 'Full Name',
                                labelStyle: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSecondary,
                                ),
                                hintStyle: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSecondary,
                                ),
                                border: const UnderlineInputBorder(),
                              ),
                            ),
                            TextField(
                              controller: phoneNumber,
                              keyboardType: TextInputType.numberWithOptions(
                                signed: false,
                                decimal: false,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                              cursorColor: Theme.of(context).colorScheme.tertiary,
                              decoration: InputDecoration(
                                hintText: 'Phone Number',
                                labelText: 'Phone Number',
                                labelStyle: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSecondary,
                                ),
                                hintStyle: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSecondary,
                                ),
                                border: const UnderlineInputBorder(),
                              ),
                            ),
                            TextField(
                              controller: email,
                              keyboardType: TextInputType.emailAddress,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                              cursorColor: Theme.of(context).colorScheme.tertiary,
                              decoration: InputDecoration(
                                hintText: 'E-mail ID',
                                labelText: 'E-mail ID',
                                labelStyle: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSecondary,
                                ),
                                hintStyle: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSecondary,
                                ),
                                border: const UnderlineInputBorder(),
                              ),
                            ),
                            TextField(
                              controller: password,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                              cursorColor: Theme.of(context).colorScheme.tertiary,
                              decoration: InputDecoration(
                                hintText: 'Password',
                                labelText: 'Password',
                                labelStyle: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSecondary,
                                ),
                                hintStyle: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSecondary,
                                ),
                                border: const UnderlineInputBorder(),
                              ),
                            ),
                            TextField(
                              controller: confirmPassword,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                              cursorColor: Theme.of(context).colorScheme.tertiary,
                              decoration: InputDecoration(
                                hintText: 'Confirm Password',
                                labelText: 'Confirm Password',
                                labelStyle: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSecondary,
                                ),
                                hintStyle: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSecondary,
                                ),
                                border: const UnderlineInputBorder(),
                              ),
                            ),
                            
                          ],
                        ),
                    ),
                  ),
                  Container( 
                    margin: EdgeInsets.only(top: 20),
                    decoration: standardTile(20),
                    child: Container(
                      margin: EdgeInsets.all(3),
                      child: TextButton(
                        onPressed: (){}, 
                        child: Text(
                          loggingIn ? 
                            "Log In" : "Sign Up",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimary,  
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.only(top: 10),
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          loggingIn = !loggingIn;
                        });
                        if (loggingIn) {
                          phoneNumber.clear();
                          password.clear();
                        }
                        else {
                          name.clear();
                          phoneNumber.clear();
                          email.clear();
                          password.clear();
                          confirmPassword.clear();
                        }
                      },
                      child: Text.rich(
                        TextSpan(
                          text: loggingIn ? 
                            "Don't have an account? " : "Already have an account? ",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSecondary,
                            fontWeight: FontWeight.normal,
                          ),
                          children: [
                            TextSpan(
                              text: loggingIn ? 
                                "Sign Up." : "Log In.",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      )
    );
  }
}