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
  final TextEditingController textController = TextEditingController();
  final TextEditingController sectionName = TextEditingController();
  DateTime? selectedDate;
  TimeOfDay? selectedTime;  
  String? selectedSection;
  bool openCompleted = false;
  bool completedSelected = false;
  Map<String ,Set<int>> selectedTaskIDs = {};
  bool allSelectedFromSection = false;

  bool areSelectedTasksEmpty() {
    return selectedTaskIDs.keys.every((sectionKey) => selectedTaskIDs[sectionKey]?.isEmpty ?? true);
  }

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

  Widget buildToDoItemTiles(
    BuildContext context, 
    String sectionTitle, 
    List<ToDoItem> toDoItems,
    bool completed,
    ) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      shrinkWrap: true,
      itemCount: toDoItems.length,
      itemBuilder: (context,index) {
        final toDoItem = toDoItems[index];
        bool pastDeadline = toDoItem.deadlineDate.isBefore(DateTime.now());
        if (!selectedTaskIDs.containsKey(sectionTitle)) {
          selectedTaskIDs[sectionTitle] = {};
        }
        final isSelected = (selectedTaskIDs[sectionTitle] ?? {}).contains(toDoItem.id);
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
          child: Container(
            decoration: standardTile(10, isSelected: isSelected),
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
                    color: completed ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.onPrimary,
                  ),
                  onPressed: () {
                    setState(() {
                      if (!completed){ 
                        sections[sectionTitle]!.remove(toDoItem);
                        if (!completedSections.containsKey(sectionTitle)){
                          completedSections[sectionTitle] = [];
                        }
                        completedSections[sectionTitle]!.add(toDoItem);
                      } else {
                        completedSections[sectionTitle]!.remove(toDoItem);
                        if (!sections.containsKey(sectionTitle)){
                          sections[sectionTitle] = [];
                        }
                        sections[sectionTitle]!.add(toDoItem);
                      }
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
                !completed ?
                  isSameDay(toDoItem.deadlineDate, DateTime.now()) ?
                  "Due Today, ${toDoItem.deadlineDate.hour.toString().padLeft(2,'0')}:${toDoItem.deadlineDate.minute.toString().padLeft(2,'0')}": 
                  "Due ${toDoItem.deadlineDate.day}/${toDoItem.deadlineDate.month}/${toDoItem.deadlineDate.year % 2000}" :
                "Completed on ${toDoItem.deadlineDate.day}/${toDoItem.deadlineDate.month}/${toDoItem.deadlineDate.year % 2000}",
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),         
              trailing: Icon(
                !completed ? 
                  pastDeadline ? 
                  Icons.watch_later_outlined : null : 
                null,
                color: Theme.of(context).colorScheme.error,
              ),
              onLongPress: () {
                setState(() {
                  if (!isSelected) {
                    if (!selectedTaskIDs.containsKey(sectionTitle)) {
                      selectedTaskIDs[sectionTitle] = {};
                    }
                    selectedTaskIDs[sectionTitle]!.add(toDoItem.id);
                  }
                });
              },
              onTap: () {
                setState(() {
                  if (!areSelectedTasksEmpty()) {
                    if (isSelected) {
                      selectedTaskIDs[sectionTitle]!.remove(toDoItem.id);
                    } else {
                      selectedTaskIDs[sectionTitle]!.add(toDoItem.id); 
                    }
                  }
                });
              },
            ),
          ),
        );
      }
    );
  }
  
  Widget buildSectionWidget(int i, bool completed) {
    String sectionKey = (completed ? completedSections : sections).keys.toList()[i];
    bool collapseSection = collapsedSections.contains(sectionKey);
    bool empty = completed ?
      completedSections[sectionKey]?.isEmpty ?? true :
      sections[sectionKey]?.isEmpty ?? true;
    
    return Column(
      children: [
        Container(
          margin: EdgeInsets.symmetric(horizontal: 40, vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              InkWell(
                onTap: () {
                  if (!completed) {
                    setState(() {
                      addingItemInSection = sectionKey;
                    });
                  }
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
                                    if (completed){
                                      completedSections.remove(sectionKey);
                                    } else {
                                      sections.remove(sectionKey);
                                    }
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
                    !completed ? Icon(
                      Icons.add,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 20,
                    ) : Container(
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
                  if (empty) {
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
                                    if (completed){
                                      completedSections.remove(sectionKey);
                                    } else {
                                      sections.remove(sectionKey);
                                    }
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
                  } else {
                    setState(() {
                      if (collapseSection) {
                        collapsedSections.remove(sectionKey);
                      } else {
                        collapsedSections.add(sectionKey);
                      }
                    });
                  }
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
                                    if (completed){
                                      completedSections.remove(sectionKey);
                                    } else {
                                      sections.remove(sectionKey);
                                    }
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
                  !empty ? 
                  collapseSection ? Icons.chevron_left : Icons.expand_more : Icons.delete_outline, 
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
                child: Column(
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
                        text: textController.text,
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
          buildToDoItemTiles(
            context, 
            sectionKey, 
            (completed ? completedSections : sections)[sectionKey]!,
            completed
          ),
        ],
      ],
    );
  }

  Widget singleFilterChip({
    required String label,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return TextButton(
      onPressed: onTap, 
      style: TextButton.styleFrom(
      backgroundColor: isSelected ? Colors.white.withAlpha(100) : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(
          color: Theme.of(context).colorScheme.onPrimary.withAlpha(100),
          width: 2,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }

  void deleteSelected() {
    
    setState(() {
      final targetMap = openCompleted ? completedSections : sections;

      for (final sectionKey in selectedTaskIDs.keys.toList()) {
        targetMap[sectionKey]!.removeWhere((item) => selectedTaskIDs[sectionKey]!.contains(item.id));
      }

      targetMap.removeWhere((key, value) => value.isEmpty);

      selectedTaskIDs.clear();
      openCompleted ? completedSections : sections = targetMap;
    });
  }

  void selectAllFromSections() {
    setState(() {
      final targetMap = openCompleted ? completedSections : sections;
      for (final sectionKey in selectedTaskIDs.keys.toList()) {
        if (selectedTaskIDs[sectionKey]?.isNotEmpty ?? false) {
        for (final item in targetMap[sectionKey]!) {
          selectedTaskIDs[sectionKey]!.add(item.id);
        }
      }
      }
    });
  }

  bool areAllSelectedFromSection() {
    final targetMap = openCompleted? completedSections : sections;

    for (final sectionKey in targetMap.keys) {
      final sectionSelectedIDs = selectedTaskIDs[sectionKey] ?? {};
      final sectionTaskIDs = targetMap[sectionKey]!.map((item) => item.id).toSet();

      if (sectionSelectedIDs.isNotEmpty) {
        if (!sectionTaskIDs.every((id) => sectionSelectedIDs.contains(id))) {
          return false;
        }
      }
    }
    return true;
  }

  void completeOrUncomplete() {
    setState(() {
      if (openCompleted) {
        // Move selected tasks from completedSections to sections (mark as to-do)
        for (final sectionKey in selectedTaskIDs.keys.toList()) {
          final idsToMove = selectedTaskIDs[sectionKey] ?? {};
          if (completedSections.containsKey(sectionKey)) {
            final itemsToMove = completedSections[sectionKey]!
                .where((item) => idsToMove.contains(item.id))
                .toList();
            // Remove from completed
            completedSections[sectionKey]!.removeWhere((item) => idsToMove.contains(item.id));
            // Add to to-do
            if (itemsToMove.isNotEmpty) {
              sections.putIfAbsent(sectionKey, () => []);
              sections[sectionKey]!.addAll(itemsToMove);
            }
          }
        }
      } else {
        // Move selected tasks from sections to completedSections (mark as completed)
        for (final sectionKey in selectedTaskIDs.keys.toList()) {
          final idsToMove = selectedTaskIDs[sectionKey] ?? {};
          if (sections.containsKey(sectionKey)) {
            final itemsToMove = sections[sectionKey]!
                .where((item) => idsToMove.contains(item.id))
                .toList();
            // Remove from to-do
            sections[sectionKey]!.removeWhere((item) => idsToMove.contains(item.id));
            // Add to completed
            if (itemsToMove.isNotEmpty) {
              completedSections.putIfAbsent(sectionKey, () => []);
              completedSections[sectionKey]!.addAll(itemsToMove);
            }
          }
        }
      }
      selectedTaskIDs.clear();
    });  
  }

  @override
  Widget build(BuildContext context) {
    allSelectedFromSection = areAllSelectedFromSection();
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
                            if (areSelectedTasksEmpty()) ...[
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
                            ] 
                            else ...[
                              IconButton(
                                icon: Icon(
                                  // ignore: dead_code
                                  allSelectedFromSection
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.circle_outlined,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                  size: 30,
                                ),
                                onPressed: () {
                                  setState(() {
                                    if (allSelectedFromSection) {
                                      selectedTaskIDs.clear();
                                    } else {
                                      selectAllFromSections();
                                    }
                                  });
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  // ignore: dead_code
                                  Icons.check,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  size: 26,
                                ),
                                onPressed: () {
                                  setState(() {
                                    completeOrUncomplete();
                                  });
                                },
                              ),
                              
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  size: 28,
                                ),
                                onPressed: () {
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
                                            'Delete Tasks?',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onPrimary,
                                            ),
                                          ),
                                          content: Text(
                                            'Selected tasks will be permanently deleted.',
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
                                                    deleteSelected();
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
                            ]
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
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    singleFilterChip(
                      label: "To-Do",
                      isSelected: !openCompleted,
                      onTap: () {
                        setState(() {
                          openCompleted = false;
                          selectedTaskIDs.clear();
                        });
                      }  
                    ),

                    singleFilterChip(
                      label: "Completed",
                      isSelected: openCompleted,
                      onTap: () {
                        setState(() {
                          openCompleted = true;
                          selectedTaskIDs.clear();
                        });
                      }  
                    )
                  
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
                          buildSectionWidget(i,false),
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
                        for (int i = 0; i < completedSections.keys.length; i++) ...[
                            buildSectionWidget(i, true),
                        ],
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
