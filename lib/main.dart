// Containts logic for home page, tabs page header and footers, and logic to call their body functions


// Dependancies
import 'package:flutter/material.dart';
import 'dart:ui';
import 'class_contacts.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'class_projects.dart';
import 'class_events.dart';
import 'class_tasks.dart';

standardTile(double borderRadius, {bool isSelected = false}) { // Code to create the common tile with the background blur
  // defiend here to avoid repeating code elsewhere
  return BoxDecoration(
    color:
        isSelected
            ? Color.fromARGB(100, 255, 255, 255)
            : Color.fromARGB(25, 255, 255, 255),
    borderRadius: BorderRadius.circular(borderRadius),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withAlpha(51),
        blurRadius: 40,
        spreadRadius: 2,
        offset: Offset(0, 12),
      ),
      BoxShadow(
        color: Colors.black.withAlpha(25),
        blurRadius: 80,
        spreadRadius: 8,
        offset: Offset(0, 24),
      ),
    ],
  );
}

void main() {
  if (Platform.isWindows) {
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
      title: 'onTop',
      // Theme stores details like the font and colours used
      theme: ThemeData( 
        fontFamily: 'Poppins',
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          primary: Colors.black,
          onPrimary: Colors.white,
          secondary: Color.fromARGB(255, 101, 28, 132),
          tertiary: Color.fromARGB(255, 200, 162, 200),
          onSecondary: Color.fromARGB(255, 88, 81, 111),
        ),
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  HomePage({super.key});
  final String username = 'usernameDefault';
  final List<String> tabs = ['Tasks', 'Contacts', 'Projects', 'Events'];

  String getGreetingTime() {
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
            Container(decoration: BoxDecoration(color: Colors.black)),
            Positioned(
              // Background blob
              top: 25, // Negative value to position it partially off-screen
              left: -35,
              child: Container(
                width: 130,
                height: 175, // Make this larger for a longer blob
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary,
                  borderRadius: BorderRadius.circular(
                    100,
                  ), // Makes it oval/elliptical
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 55, sigmaY: 40),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: IconButton(
                onPressed: () {},
                icon: Icon(
                  Icons.person_2_outlined,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 35,
                ),
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
            children: [ // Appbar with name and greeting
              SizedBox(height: 5),
              Text(
                "onTop.",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 40,
                ),
              ),
              Column(
                children: [
                  Text(
                    "Good $greetingTime,",
                    style: TextStyle( fontSize: 20),
                  ),
                  Text(
                    widget.username,
                    style: const TextStyle( fontSize: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned( // The purple blob you see in the background, set behind the text and tiles
            right: -75,
            top: MediaQuery.of(context).size.height * 0.35,
            child: Container(
              width: 160,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.secondary,
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // for loop creates a new tile automatically, so we only need to add a string the tabs
                for (int index = 0; index < widget.tabs.length; index++) 
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    child: Container(
                      decoration: standardTile(50),
                      margin: const EdgeInsets.symmetric(horizontal: 25),
                      child: ListTile(
                        title: Center(
                          child: Text( // Title of the tab
                            widget.tabs[index],
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        onTap: () {
                          Navigator.push( // Redirect to tab
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => Tabs(
                                    currentIndex: index,
                                    tabs: widget.tabs,
                                  ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Tabs extends StatefulWidget {
  const Tabs({super.key, required this.currentIndex, required this.tabs});
  final int currentIndex;
  final List<String> tabs;

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
    List<String> drawerTabs = ['Home', ...widget.tabs]; // initialize the list with drawer tiles
    return Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar(
        // most of the following is to avoid the body showing up behing the appbar and affecting the background colours
        elevation: 0, 
        surfaceTintColor: Colors.transparent, 
        scrolledUnderElevation: 0, 
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        toolbarHeight: MediaQuery.of(context).size.height * 0.15,
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onPrimary,
        ),
        actions: [Container()], 
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
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "onTop.",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 40),
              ),
              Builder( // sidebar requires context, hence the builder widget 
              // instead of directly creating an iconButton
                builder:
                    (context) => IconButton(
                      icon: const Icon(Icons.menu, size: 35),
                      onPressed: () => Scaffold.of(context).openEndDrawer(),
                    ),
              ),
            ],
          ),
        ),
      ),
      body: TabsContentCaller(tab: index), // Calls tabsContentCaller with index of tab required
      // cleaner that writing the code here
      endDrawer: Drawer( // Sidebar code
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Container( 
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                width: 1.5,
                color: Theme.of(context).colorScheme.tertiary,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end, // FOr right aligned icons
            children: [ // Close sidebar button
              IconButton(
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                icon: Icon(Icons.arrow_forward, color: Colors.white, size: 30),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).size.height * 0.10, // Vertical offset
                  ),
                  itemCount: drawerTabs.length,
                  separatorBuilder: // Add in the gap and the horizontal line between tiles
                    (context, index) => Container(
                      height: 3,
                      margin: EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        border: Border(
                          bottom: BorderSide(
                            width: 1.5,
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                        ),
                      ),
                    ),
                  itemBuilder:
                    (context, drawerIndex) => ListTile(
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 30,
                      ),
                      title: Text( // Contains the text of the list tile and text style
                        drawerTabs[drawerIndex],
                        style: TextStyle(
                          color:
                            drawerIndex - 1 == index // make the text white if this tile is currently opened
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.tertiary,
                          fontSize: 18,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      onTap: () {
                        if (drawerIndex == 0) { // home is at index 0, special case for it
                          Navigator.pushAndRemoveUntil( // redirect to home, kill the history of the previous tabs visited
                            context,
                            MaterialPageRoute(
                              builder: (context) => HomePage(),
                            ),
                            (route) => false, // just means no tab other than home should be in stack
                          );
                        } else {
                          Navigator.pop(context); // Remove Sidebar
                          Navigator.push( context, // Open clicked-on tab
                            MaterialPageRoute(
                              builder:
                                  (context) => Tabs(
                                    currentIndex: drawerIndex - 1,
                                    tabs: widget.tabs,
                                  ),
                            ),
                          );
                        }
                      },
                    ),
                ),
              ),
              IconButton( // Profile and Settings Button, currently a dummy
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                icon: Icon(Icons.person_outline, color: Colors.white, size: 30),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// This class just returns the body of the specific tab called
class TabsContentCaller extends StatelessWidget {
  const TabsContentCaller({super.key, required this.tab});
  final int tab;
  // tabs list for index reference
  /*'Tasks',
    'Contacts',
    'Projects',
    'Events'*/
  @override
  Widget build(BuildContext context) {
    switch (tab) {
      case 1:
        return Contacts();

      case 2:
        return Projects();

      case 3:
        return Events();

      case 0:
        return Tasks();

      default:
        return Text("$tab Body not added or wrong index passed");
    }
  }
}
