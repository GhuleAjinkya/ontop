import 'package:flutter/material.dart';
import 'main.dart';

class ToDoItem {
  final int id;
  String text;
  TimeOfDay deadlineTime;
  DateTime deadlineDate;

  ToDoItem({
    required this.id,
    required this.text,
    required this.deadlineDate,
    required this.deadlineTime,
  });
}

class Tasks extends StatefulWidget {
  const Tasks({super.key});

  @override
  State<Tasks> createState() => _TasksState();
}

class _TasksState extends State<Tasks> { 

  Map<String, List<ToDoItem>> sections = {};

  Widget buildToDoItemTiles(BuildContext context, title, List<ToDoItem> toDoItems, {bool completed = false}) {
    
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      shrinkWrap: true,
      itemCount: toDoItems.length,
      itemBuilder: (context,index) {
        // ignore: unused_local_variable
        final toDoItem = toDoItems[index];
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
          child: Container(
            decoration: standardTile(10),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: ListTile(
              dense: true,
              leading: Icon(
                completed ? Icons.check_circle_outline : Icons.circle_outlined,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        );
      }
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: Container(
          color: Theme.of(context).colorScheme.primary,
          child: Column(
            children: [
              Container(
                color: Theme.of(context).colorScheme.primary,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        margin: EdgeInsets.only(left: 40),
                        child: Text(
                          'Tasks',
                          style: TextStyle(
                            fontSize: 28,
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.only(right: 20),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.add, 
                                color: Theme.of(context).colorScheme.onPrimary,
                                size: 30,
                              ),
                              onPressed: () {
                              }
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.more_vert, 
                                color: Theme.of(context).colorScheme.onPrimary,
                                size: 26,
                              ),
                              onPressed: () {
                              }
                            ),
                          ],
                        ),
                        ),                  
                    ],
                  ),
                ),
              ),
              Spacer(),
              Text(
                "You have not added any tasks yet.",
                style: TextStyle(
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.tertiary, 
                ),
                textAlign: TextAlign.center,
              ),
              Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
