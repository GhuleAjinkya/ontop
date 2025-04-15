import 'package:flutter/material.dart';

class Contact {
  final String name;
  final String organization;
  final String phoneNumber;

  Contact({
    required this.name,
    required this.organization, 
    required this.phoneNumber,
  });
}

class Contacts extends StatefulWidget {
  const Contacts({super.key});

  @override
  State<Contacts> createState() => _ContactsState();
}

class _ContactsState extends State<Contacts> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ListView.builder(
          itemBuilder: (context,index) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.orange[400],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(

                ),
              ),
            );
          },
        ),
      ),
    );
  }
}