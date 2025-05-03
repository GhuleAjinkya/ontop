import 'package:flutter/material.dart';
import 'main.dart';

class ToDoItem {
  final int id;
  String text;
  DateTime deadlineDate;

  ToDoItem({
    required this.id,
    required this.text,
    required this.deadlineDate,
  });
}

class Tasks extends StatefulWidget {
  const Tasks({super.key});

  @override
  State<Tasks> createState() => _TasksState();
}

class _TasksState extends State<Tasks> { 

  Map<String, List<ToDoItem>> sections = {};
  List<ToDoItem> tempItems = [];
  int tempID = 0;

  bool isSameDay(DateTime day1, DateTime day2) {
    return day1.year == day2.year &&
    day1.month == day2.month &&
    day1.day == day2.day;
  }
  Widget buildToDoItemTiles(BuildContext context, sectionTitle, List<ToDoItem> toDoItems, {bool completed = false}) {
    
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
              minLeadingWidth: 0,
              selected: false,
              dense: true,
              leading: Container(
                margin: EdgeInsets.all(0),
                child: IconButton(
                  icon: Icon(

                    completed ? Icons.check_circle_outline : Icons.circle_outlined,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  onPressed: () {
                    setState(() {
                      // The function to move this to completedToDoItems will be called here.
                    });
                  },
                ),
              ),
              title: Text(
                toDoItem.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              subtitle: Text(
                isSameDay(toDoItem.deadlineDate, DateTime.now()) ?
                "Due Today, ${toDoItem.deadlineDate.hour}:${toDoItem.deadlineDate.minute}": 
                "Due ${toDoItem.deadlineDate.day}/${toDoItem.deadlineDate.month}/${toDoItem.deadlineDate.year % 2000}",
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
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
                                setState(() {
                                  tempItems.add(ToDoItem(id: tempID, text: "test #$tempID", deadlineDate: DateTime.parse("2025-05-03 16:38")));
                                  tempID += 1;
                                });
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
              
              Expanded(
                child: buildToDoItemTiles(context, "tempSection", tempItems)
              ),
            ],
          ),
        ),
      ),
    );
  }
}
