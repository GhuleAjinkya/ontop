// Containts logic for home page, tabs page header and footers, and logic to call their bod functions

import 'package:flutter/material.dart';
import 'class_contacts.dart';

const LinearGradient appGradient = LinearGradient(
              colors: [Colors.orange,Colors.deepOrange],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            );
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange, primary: Colors.orange),
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  HomePage({super.key});
  final String username = 'usernameDefault';
  final List<Map<String, IconData>> pages = [
  {'Contacts': Icons.contact_phone_rounded},
  {'Docket': Icons.abc},
  {'Projects': Icons.abc},
  {'Notes': Icons.abc},
  {'Events': Icons.event}];
  /* Old pages:
  {'Contacts': Icons.contact_phone_rounded},
  {'Events': Icons.event},
  {'To-Do': Icons.abc},
  {'Projects': Icons.abc},
  {'Reminders': Icons.abc},
  {'Notes': Icons.abc}];
  */
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
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            border : Border(
              bottom: BorderSide(
                color: Colors.black,
                width: 2.0,
              ),
            ),
            gradient: appGradient
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Good $greetingTime,',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              widget.username,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            )
          ],
        ), 
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int index = 0; index < widget.pages.length; index++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child : Container(
                  decoration: BoxDecoration(
                    color: Colors.orange.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 25),
                  child: ListTile(
                    leading: Icon(widget.pages[index].values.first, color: Colors.black, size: 30,),
                    title: Center(
                      child: Text(widget.pages[index].keys.first, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),),
                    ),
                    onTap: (){
                      Navigator.push(context, MaterialPageRoute(builder: (context) => Tabs(
                        currentIndex: index,
                        pages: widget.pages)));
                    },
                  ),
                ),
              ),
          ]
        ),
      )
    );
  }
}

class Tabs extends StatefulWidget {
  const Tabs({super.key, required this.currentIndex, required this.pages});
  final int currentIndex;
  final List<Map<String, IconData>> pages;
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
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            border : Border(
              bottom: BorderSide(
                color: Colors.black,
                width: 2.0,
              ),
            ),
            gradient: appGradient,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, 
          crossAxisAlignment: CrossAxisAlignment.center,  
          children: [
            Row(
              spacing: 10,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [ 
                Icon(widget.pages[index].values.first, color: Colors.white, size: 40,),
                Text(widget.pages[index].keys.first, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.home, color: Colors.white, size: 35),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: TabsContentCaller(index: index),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.orange,
          border: Border(
            top: BorderSide(
              color: Colors.black,
              width: 2.0,
            ),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          currentIndex: index,
          items: [
            for (var page in widget.pages)
              BottomNavigationBarItem(
                icon: Icon(page.values.first),
                label: page.keys.first,
              )
          ],
          onTap: (currentIndex) {
            setState(() {
              index = currentIndex;
            });
          },
          selectedLabelStyle: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.black,
          showUnselectedLabels: true,
          showSelectedLabels: true,
          type: BottomNavigationBarType.fixed,
        ),
      ),
    );
  }
}

class TabsContentCaller extends StatelessWidget {
  const TabsContentCaller({super.key, required this.index});
  final int index;
  @override
  Widget build(BuildContext context) {
    /* {'Contacts': Icons.contact_phone_rounded},
  {'Docket': Icons.abc},
  {'Projects': Icons.abc},
  {'Notes': Icons.abc},
  {'Events': Icons.event}]; 
  Pages for referance */
    switch (index) {
      case 0:
        return Contacts(); 
      case 2:
        // return Projects();
      default:
        return const Text("Wrong index passed as an arguement from _TabsState");
    }
  }
}