import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
      ),
      home: const MyHomePage(title: 'Flutter Primary Testing'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // List of strings to display as dropdown items
  final List<String> _items = ['Contacts', 'Events', 'Workplaces', 'To-Do', 'Notes'];

  // List of titles for the navbar
  final List<String> _navbarTitles = ['Home', 'Profile', 'Settings', 'Notifications', 'Help'];

  // String for tracking selected navbar title
  String _selectedNavbarTitle = "";
  // Placeholder function for navbar button actions
  void _onNavbarButtonPressed(String title) {
    setState(() {
      _selectedNavbarTitle = title;
    });
    print('$title button pressed');
  }

  // Placeholder function for dropdown button actions
  void _onButtonPressed(String item) async {
    final message = '$item selected';
    print(message);

    // Add the message to the log
    setState(() {
      _logMessages.add(message);
    });

    // Save the log to a JSON file
    await _saveLogToFile();
  }

  // List to store selected items for logging
  final List<String> _logMessages = [];

  // Function to get the correct directory for storing the file
  Future<Directory> _getStorageDirectory() async {
    return await getApplicationDocumentsDirectory();
  }

  // Function to save the log to a JSON file
  Future<void> _saveLogToFile() async {
    try {
      final directory = await _getStorageDirectory();
      final file = File('${directory.path}/test_logs.json');

      // Write the log messages to the file as JSON
      await file.writeAsString(jsonEncode(_logMessages));
    } catch (e) {
      print('Error writing to file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          // Navbar at the top
          Container(
          alignment: Alignment.topLeft,
          padding: const EdgeInsets.symmetric(vertical: 10.0,horizontal: 8.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center, // Align items to the left
              children: _navbarTitles.map((title) {
                final bool isSelected = _selectedNavbarTitle == title;
                  return AnimatedContainer(
                    padding: EdgeInsets.zero,
                    duration: const Duration(milliseconds: 200), // Smooth transition
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    height: isSelected ? 35.0 : 30.0, // Taller when selected
                    width: isSelected ? 110.0 : 100.0, // Wider when selected
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white, // Background color
                        foregroundColor: Colors.black, // Text color
                        side: const BorderSide(color: Colors.black, width: 1), // Border styling
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero, // Rectangular shape
                        ),
                        padding: EdgeInsets.zero, // Remove internal padding
                      ),
                      onPressed: () => _onNavbarButtonPressed(title),
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, // Bold if selected
                        ),
                      ),),);
                }).toList(),
                
              ),
            ),
          ),
          // Main content
          Expanded(
            child: Center(
              child: Text(
                'Press the "+" button to open the dropdown.',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: PopupMenuButton<String>(
        icon: const Icon(Icons.add),
        tooltip: 'Open Dropdown',
        onSelected: (String item) {
          _onButtonPressed(item); // Call the function when an item is selected
        },
        itemBuilder: (BuildContext context) {
          return _items.map((String item) {
            return PopupMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList();
        },
        offset: const Offset(0, -200), // Adjusts the dropdown to open upwards
      ),
    );
  }
}