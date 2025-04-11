// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange, primary: Colors.orange),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: MyHomePage(title: '...'),
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

  final String username = 'Test';
  String getGreetingTime() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Morning';
    } else if (hour < 17) {
      return 'Afternoon';
    } else {
      return 'Evening';
    }
  }

  final List<IconData> icons = [Icons.contact_phone_rounded, Icons.event, Icons.abc, Icons.abc, Icons.abc, Icons.abc];
  final List<String> titles = ['Contacts', 'Events', 'To-Do','Projects','Reminders','Notes'];
  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    final String greetingTime = getGreetingTime();
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepOrange, Colors.orange], // Darker to lighter orange
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              ),
            border: Border(
              bottom: BorderSide(
                color: Colors.black,
                width: 2.0, // Border width
              ),
            )
          ),
        ),
        toolbarHeight: 100,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good $greetingTime,',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize : 30,
                    color : Colors.white, 
                  ),
                ),
                Text(
                  username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 35,
                ),
              )
            ],
          ),
          
          IconButton(
              icon: const Icon(Icons.settings, color: Colors.white, size: 35),
              onPressed: () {
                print('Settings button pressed');
              },
            ),
          ],
        ), 
      ), 
      body: Center(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: titles.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 25),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade300,
                    borderRadius: BorderRadius.circular(10),

                  ),
                  child: ListTile(
                    leading: Icon(icons[index], color: Colors.black,),
                    title: Center(
                      child: Text(
                        titles[index],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    onTap: () {
                      
                      print('Tapped on ${titles[index]}');
                    },
                  ),
              ),
            );
          },
        ), 
      )
    );
  }
}
