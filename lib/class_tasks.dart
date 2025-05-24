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
  Map<String, List<ToDoItem>> completedSections = {};
  List<ToDoItem> tempItems = [];
  int tempID = 0;
  String? addingItemInSection;
  bool addingSection = false;
  List<String> collapsedSections = [];
  List<String> collapsedCompletedSections = [];
  final TextEditingController textController = TextEditingController();
  final TextEditingController sectionName = TextEditingController();
  DateTime? selectedDate;
  TimeOfDay? selectedTime;  
  String? selectedSection;
  bool openCompleted = false;

  bool isSameDay(DateTime day1, DateTime day2) {
    return day1.year == day2.year &&
    day1.month == day2.month &&
    day1.day == day2.day;
  }

  void clearItem() {
    setState(() {
      addingItemInSection = null;
      addingSection = false;
    });
  }

  Widget buildToDoItemTiles(BuildContext context, String sectionTitle, List<ToDoItem> toDoItems) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      shrinkWrap: true,
      itemCount: toDoItems.length,
      itemBuilder: (context,index) {
        final toDoItem = toDoItems[index];
        bool pastDeadline = toDoItem.deadlineDate.isBefore(DateTime.now());
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
                    Icons.circle_outlined,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  onPressed: () {
                    setState(() {
                      if (!completedSections.containsKey(sectionTitle)) {
                        completedSections[sectionTitle] = [];
                      }
                      completedSections[sectionTitle]!.add(toDoItem);
                      sections[sectionTitle]!.remove(toDoItem);
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
                "Due Today, ${toDoItem.deadlineDate.hour.toString().padLeft(2,'0')}:${toDoItem.deadlineDate.minute.toString().padLeft(2,'0')}": 
                "Due ${toDoItem.deadlineDate.day}/${toDoItem.deadlineDate.month}/${toDoItem.deadlineDate.year % 2000}",
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
              
              trailing: Icon(
                pastDeadline ? 
                Icons.watch_later_outlined : null,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        );
      }
    );
  }
  
  Widget buildSectionWidget(int i) {
    String sectionKey = sections.keys.toList()[i];
    bool collapseSection = collapsedSections.contains(sectionKey);
    return Column(
      children: [
        Container(
          margin: EdgeInsets.symmetric(horizontal: 40, vertical: 5),
          //height: 20,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    addingItemInSection = sectionKey;
                  });
                },
                onLongPress: () {
                  showDialog(
                    context: context,
                    builder:
                      (context) => AlertDialog(
                        backgroundColor:
                            Theme.of(
                              context,
                            ).colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            10,
                          ),
                          side: BorderSide(
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.onSecondary,
                            width: 1.5,
                          ),
                        ),
                        title: Text(
                          'Delete Section "$sectionKey"?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.onPrimary,
                          ),
                        ),
                        content: Text(
                          'Selected section will be permanently deleted.',
                          style: TextStyle(
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.onPrimary,
                          ),
                        ),
                        actions: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                onPressed:
                                    () => Navigator.pop(
                                      context,
                                    ),
                                icon: Icon(
                                  Icons.close,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                  size: 30,
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    sections.remove(sectionKey);
                                  });
                                  Navigator.pop(context);
                                },
                                icon: Icon(
                                  Icons.check,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.error,
                                  size: 30,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                  );
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 20,
                    ),
                    Text(
                      sectionKey,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(left: 10),
                  height: 1,
                  decoration: BoxDecoration(
                    border: Border.all(
                      width: 2,
                      color: Theme.of(context).colorScheme.onPrimary,
                    )
                  ),
                ),
              ),
              IconButton(
                alignment: Alignment.topCenter,
                onPressed: () {
                  setState(() {
                    if (collapseSection) {
                      collapsedSections.remove(sectionKey);
                    } else {
                      collapsedSections.add(sectionKey);
                    }
                  });
                },
                onLongPress: () {
                  showDialog(
                    context: context,
                    builder:
                      (context) => AlertDialog(
                        backgroundColor:
                            Theme.of(
                              context,
                            ).colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            10,
                          ),
                          side: BorderSide(
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.onSecondary,
                            width: 1.5,
                          ),
                        ),
                        title: Text(
                          'Delete Section "$sectionKey"?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.onPrimary,
                          ),
                        ),
                        content: Text(
                          'Selected section will be permanently deleted.',
                          style: TextStyle(
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.onPrimary,
                          ),
                        ),
                        actions: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                onPressed:
                                    () => Navigator.pop(
                                      context,
                                    ),
                                icon: Icon(
                                  Icons.close,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                  size: 30,
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    sections.remove(sectionKey);
                                  });
                                  Navigator.pop(context);
                                },
                                icon: Icon(
                                  Icons.check,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.error,
                                  size: 30,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                  );
                },
                icon: Icon(
                  collapseSection ? Icons.chevron_left : Icons.expand_more, 
                  size: 20,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        ),
        if (addingItemInSection == sectionKey) ...[
          Container(
            margin: const EdgeInsets.symmetric(
              horizontal: 36,
              vertical: 5,
            ),
            decoration: standardTile(10),
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 2),
              leading: IconButton(
                alignment: Alignment.centerLeft,
                onPressed: clearItem,
                icon: Icon(
                  Icons.close,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 20,
                ),
              ),
              title: SizedBox(
                child: TextField(
                  controller: textController,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  cursorColor: Theme.of(context).colorScheme.tertiary,
                  decoration: InputDecoration(
                    hintText: 'Details',
                    labelText: 'Details*',
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondary,
                    ),
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondary,
                    ),
                    border: const UnderlineInputBorder(),
                  ),
                ),
              ),
              subtitle: Container(
                margin: EdgeInsets.only(top: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      icon: Icon(Icons.calendar_today, size: 16, color: Theme.of(context).colorScheme.onPrimary),
                      label: Text(
                        selectedDate != null
                            ? "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}"
                            : "Pick date",
                        style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 12),
                      ),
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? now,
                          firstDate: now,
                          lastDate: DateTime(now.year + 5),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                    ),
                    TextButton.icon(
                      icon: Icon(Icons.access_time, size: 16, color: Theme.of(context).colorScheme.onPrimary),
                      label: Text(
                        selectedTime != null
                            ? "${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}"
                            : "Pick time",
                        style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 12),
                      ),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime ?? TimeOfDay.now(),
                          initialEntryMode: TimePickerEntryMode.inputOnly,
                        );
                        if (picked != null) {
                          setState(() {
                            selectedTime = picked;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              trailing: IconButton(
                alignment: Alignment.centerRight,
                onPressed: () {
                  if (selectedDate != null && selectedTime != null && textController.text.isNotEmpty) {
                    final deadline = DateTime(
                      selectedDate!.year,
                      selectedDate!.month,
                      selectedDate!.day,
                      selectedTime!.hour,
                      selectedTime!.minute,
                    );
                    setState(() {
                      sections[sectionKey]!.add(ToDoItem(
                        id: tempID,
                        text: textController.text.isNotEmpty ? textController.text : "test $tempID",
                        deadlineDate: deadline,
                      ));
                      tempID += 1;
                      addingItemInSection = null;
                      textController.clear();
                      selectedDate = null;
                      selectedTime = null;
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'All fields are required',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onError,
                          ),
                        ),
                        backgroundColor: Theme.of(context).colorScheme.error,
                        duration: Duration(seconds: 2),
                        showCloseIcon: true,
                        closeIconColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                    );
                  }
                },
                icon: Icon(
                  Icons.check,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
        if (!collapseSection) ...[
          buildToDoItemTiles(context, sectionKey, sections[sectionKey]!),
        ],
      ],
    );
  }

  Widget buildCompletedSectionWidget(int i) {

    String sectionKey = completedSections.keys.toList()[i];
    bool collapseSection = collapsedCompletedSections.contains(sectionKey);

    return Column(
      children: [
        Container(
          margin: EdgeInsets.symmetric(horizontal: 40, vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              TextButton(
                child: Text(
                  sectionKey,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                onPressed: () {},
                onLongPress: () {
                  showDialog(
                    context: context,
                    builder:
                      (context) => AlertDialog(
                        backgroundColor:
                            Theme.of(
                              context,
                            ).colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            10,
                          ),
                          side: BorderSide(
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.onSecondary,
                            width: 1.5,
                          ),
                        ),
                        title: Text(
                          'Delete Section "$sectionKey"?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.onPrimary,
                          ),
                        ),
                        content: Text(
                          'Selected section will be permanently deleted.',
                          style: TextStyle(
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.onPrimary,
                          ),
                        ),
                        actions: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                onPressed:
                                    () => Navigator.pop(
                                      context,
                                    ),
                                icon: Icon(
                                  Icons.close,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                  size: 30,
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    completedSections.remove(sectionKey);
                                  });
                                  Navigator.pop(context);
                                },
                                icon: Icon(
                                  Icons.check,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.error,
                                  size: 30,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                  );
                },
              ),
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(left: 10),
                  height: 1,
                  decoration: BoxDecoration(
                    border: Border.all(
                      width: 2,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
              IconButton(
                alignment: Alignment.topCenter,
                onPressed: () {
                  setState(() {
                    if (collapseSection) {
                      collapsedCompletedSections.remove(sectionKey);
                    } else {
                      collapsedCompletedSections.add(sectionKey);
                    }
                  });
                },
                onLongPress: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.onSecondary,
                          width: 1.5,
                        ),
                      ),
                      title: Text(
                        'Delete Section "$sectionKey"?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                      content: Text(
                        'Selected section will be permanently deleted.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                      actions: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(
                                Icons.close,
                                color: Theme.of(context).colorScheme.onPrimary,
                                size: 30,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  completedSections.remove(sectionKey);
                                });
                                Navigator.pop(context);
                              },
                              icon: Icon(
                                Icons.check,
                                color: Theme.of(context).colorScheme.error,
                                size: 30,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
                icon: Icon(
                  collapseSection ? Icons.chevron_left : Icons.expand_more,
                  size: 20,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        ),
        if (!collapseSection)
          ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: completedSections[sectionKey]!.length,
            itemBuilder: (context, index) {
              final toDoItem = completedSections[sectionKey]![index];
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
                child: Container(
                  decoration: standardTile(10),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  child: ListTile(
                    minLeadingWidth: 0,
                    selected: false,
                    dense: true,
                    leading: IconButton(
                      icon: Icon(
                        Icons.check_circle_outline,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                      onPressed: () {
                        setState(() {
                          if (!sections.containsKey(sectionKey)) {
                            sections[sectionKey] = [];
                          }
                          sections[sectionKey]!.add(toDoItem);
                          completedSections[sectionKey]!.remove(toDoItem);
                        });
                      },
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
                      "Completed on ${toDoItem.deadlineDate.day}/${toDoItem.deadlineDate.month}/${toDoItem.deadlineDate.year % 2000}",
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
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
                                  addingSection = true;
                                  openCompleted = false;
                                  selectedSection = sections.isNotEmpty ? sections.keys.first : null;
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
              Container(
                margin: EdgeInsets.only(left: 10, right: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Container(
                        height: 2,
                        margin: EdgeInsets.only(left: 15),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: Theme.of(context).colorScheme.tertiary,
                              width: 2,
                            )
                          )
                        ),
                      ),
                    ),
                    TextButton(
                      child: Text(
                        "To-Do",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: openCompleted ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.onPrimary,
                          fontSize: 20
                        ),
                        textAlign: TextAlign.center,
                      ),
                      onPressed: () {
                        setState(() {
                          openCompleted = false;
                        });
                      },
                    ),
                    Expanded(
                      child: Container(
                        height: 2,
                        margin: EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: Theme.of(context).colorScheme.tertiary,
                              width: 2,
                            )
                          )
                        ),
                      ),
                    ),

                    Expanded(
                      child: Container(
                        height: 2,
                        margin: EdgeInsets.only(left: 5),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: Theme.of(context).colorScheme.tertiary,
                              width: 2,
                            )
                          )
                        ),
                      ),
                    ),
                    TextButton(
                      child: Text(
                        "Completed",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: openCompleted ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.tertiary,
                          fontSize: 20
                        ),
                        textAlign: TextAlign.center,
                      ),
                      onPressed: () {
                        setState(() {
                          openCompleted = true;
                        });
                      },
                    ),
                    Expanded(
                      child: Container(
                        height: 2,
                        margin: EdgeInsets.only(right: 15),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: Theme.of(context).colorScheme.tertiary,
                              width: 2,
                            )
                          )
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!openCompleted) ...[
                if (addingSection) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 36,
                      vertical: 5,
                    ),
                    decoration: standardTile(10),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 2),
                      leading: IconButton(
                        alignment: Alignment.centerLeft,
                        onPressed: clearItem,
                        icon: Icon(
                          Icons.close,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 20,
                        ),
                      ),
                      title: TextField(
                        controller: sectionName,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                        cursorColor: Theme.of(context).colorScheme.tertiary,
                        decoration: InputDecoration(
                          hintText: 'New Section',
                          labelText: 'New Section',
                          labelStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onSecondary,
                          ),
                          hintStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onSecondary,
                          ),
                          border: const UnderlineInputBorder(),
                        ),
                      ),
                      trailing: IconButton(
                        alignment: Alignment.centerRight,
                        onPressed: () {
                          if (sectionName.text.isNotEmpty) {
                            setState(() {
                              if (!sections.containsKey(sectionName.text)) {
                                sections[sectionName.text] = [];
                              }
                              else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Section "${sectionName.text}" already.',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onError,
                                      ),
                                    ),
                                    backgroundColor: Theme.of(context).colorScheme.error,
                                    duration: Duration(seconds: 2),
                                    showCloseIcon: true,
                                    closeIconColor: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                );
                              }
                              addingSection = false;
                              sectionName.clear();
                            });
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Section Name not entered.',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onError,
                                  ),
                                ),
                                backgroundColor: Theme.of(context).colorScheme.error,
                                duration: Duration(seconds: 2),
                                showCloseIcon: true,
                                closeIconColor: Theme.of(context).colorScheme.onPrimary,
                              ),
                            );
                          }
                        },
                        icon: Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
                Expanded(
                  child: ListView(
                    children: [
                      if (sections.isNotEmpty) ...[
                        for (int i = 0; i < sections.keys.length; i++) ...[
                          buildSectionWidget(i),
                        ],
                      ]
                    ],
                  ),
                ),
              ] else ...[
                if (completedSections.isNotEmpty) ...[
                  Expanded(
                    child: ListView(
                      children: [
                        if (completedSections.isNotEmpty) ...[
                          for (int i = 0; i < completedSections.keys.length; i++) ...[
                            buildCompletedSectionWidget(i,),
                          ],
                        ]
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
