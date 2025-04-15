import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class Contact {
  final String name;
  final String organization;
  final String phoneNumber;

  Contact({
    required this.name,
    required this.organization, 
    required this.phoneNumber,
  });

  Map<String, String> toJSON() {
    return {
      'name': name,
      'organization': organization,
      'phoneNumber': phoneNumber,
    };  
  }

 factory Contact.fromJSON(Map<String, String> json) {
    return Contact(
      name: json['name'] as String,
      organization: json['organization'] as String,
      phoneNumber: json['phoneNumber'] as String,
    );
  }
 
}

class JSONHelper {
  static const String fileName  ='contacts.json';
  
  Future<File> getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$fileName');
  }


}

class Contacts extends StatefulWidget {
  const Contacts({super.key});
  // To-Do Wrap homepage and tabspage icons in HERO widgets to smooth out UI
  // Understand backend
  
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
                  onTap: () {

                  },
                ),
                
              ),
            );
          },
        ),
      ),
    );
  }
}