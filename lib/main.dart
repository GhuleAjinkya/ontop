// Containts logic for home page, tabs page header and footers, and logic to call their body functions

import 'package:flutter/material.dart';
import 'dart:ui';
import 'class_contacts.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS){
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const MyApp());
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        fontFamily: 'Poppins',
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black, 
          primary: Colors.black,
          onPrimary: Colors.white,
          secondary: Color.fromARGB(255, 101, 28, 132),
          tertiary: Color.fromARGB(255, 200, 162, 200)
          ),
      ),
      home: HomePage(),
    );
  }
}
class HomePage extends StatefulWidget {
  HomePage({super.key});
  final String username = 'usernameDefault';
  final List<Map<String, IconData>> tabs = [
  {'Contacts': Icons.contact_phone_rounded},
  {'Docket': Icons.note},
  {'Projects': Icons.abc},
  {'Notes': Icons.abc},
  {'Events': Icons.event}];

  String getGreetingTime(){
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Morning';
    }
    if (hour < 17) {
      return 'Afternoom';
    }
    return 'Evening';
  }
  @override
  State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  String greetingTime = 'notInitialized';
  @override
  void initState() {
    super.initState();
    greetingTime = widget.getGreetingTime();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar( 
        backgroundColor: Theme.of(context).colorScheme.primary,
        toolbarHeight: MediaQuery.of(context).size.height * 0.33,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        flexibleSpace: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.black,
              ),
            ),
            Positioned(  // Background blob
              top: 25,  // Negative value to position it partially off-screen
              left: -35,
              child: Container(
                width: 125,
                height: 125,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 55,
                    sigmaY: 40,
                  ),
                  child: Container(
                    color: Colors.transparent,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () {
                  
                }, 
                icon: Icon(
                  Icons.person_2_outlined,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 35,
                  )
                ),
            ),
          ],
          ),
        centerTitle: true,
        titleSpacing: 10,
        title: SizedBox(
          child: Column(
            spacing: 20,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 5,),
              Text(
                "onTop.",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 40,
                ),
              ),
              Column(
                children: [
                  Text(
                    "Good $greetingTime,",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 20,
                    ),
                  ),
                  Text(
                    widget.username,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 20,
                    ),
                  ),
                ],
              )
            ],
          )
        )
      ),
      body: Stack(
        children: [
          Positioned(
            right: -75, 
            top: MediaQuery.of(context).size.height * 0.35, 
            child: Container(
              width: 175,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.secondary,
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 100,
                  sigmaY: 100,
                ),
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
          ),
          Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int index = 0; index < widget.tabs.length; index++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child : Container(
                    decoration: BoxDecoration(
                      color: Color.fromARGB(25, 255, 255, 255),
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: Color.fromARGB(10, 255, 255, 255), //color: Color.fromARGB(255, 201, 185, 253)
                          blurRadius: 15,
                          spreadRadius: 0,
                        ),
                      ],  
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 25),
                    child: ListTile(
                      title: Center(
                        child: Text(widget.tabs[index].keys.first, style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold),),
                      ),
                      onTap: (){
                        Navigator.push(context, MaterialPageRoute(builder: (context) => Tabs(
                          currentIndex: index,
                          tabs: widget.tabs)));
                      },
                    ),
                  ),
                ),
            ]
          ),
        ),
        ],
      )
    );  
  }
}

class Tabs extends StatefulWidget {
  const Tabs({super.key, required this.currentIndex, required this.tabs});
  final int currentIndex;
  final List<Map<String, IconData>> tabs;

  @override
  State<Tabs> createState() => _TabsState();
}
class _TabsState extends State<Tabs> {
  int index = 0;
  
  @override
  void initState() {
    super.initState();
    index = widget.currentIndex;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar(
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        toolbarHeight: MediaQuery.of(context).size.height * 0.15,
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onPrimary,),
        title: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.onPrimary,
                width: 2.0,
              ),
            )
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            crossAxisAlignment: CrossAxisAlignment.start,  
            children: [
              Text(
                "onTop.",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 40,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.menu_rounded, size: 35),
                onPressed: () {
                  Navigator.pop(context); // Go back to the previous screen
                },
              ),
            ],
          ),
        ),
      ),
      //body: TabsContentCaller(tab: index),
    );
  }
}

class TabsContentCaller extends StatelessWidget {
  const TabsContentCaller({super.key, required this.tab});
  final int tab;

  @override
  Widget build(BuildContext context) {
    /* {'Contacts': Icons.contact_phone_rounded},
  {'Docket': Icons.note},
  {'Projects': Icons.abc},
  {'Notes': Icons.abc},
  {'Events': Icons.event}]; 
  Pages for referance */
    switch (tab) {
      case 0:
        return Contacts(); 
      default:
        return const Text("Body not added");
    }
  }
}