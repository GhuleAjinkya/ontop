import 'package:asep_app/models/contact.dart' as model_contact;
import 'package:flutter/material.dart';
import 'models/project.dart';
import 'models/to_do_item.dart';
import 'main.dart';
import 'class_contacts.dart' as local_contact;

class Projects extends StatefulWidget {
  const Projects({super.key});

  @override
  State<Projects> createState() => _ProjectsState();
}

class _ProjectsState extends State<Projects> {
  List<Project> projects = [];
  bool addingProject = false;
  TextEditingController projectTitle = TextEditingController();
  int tempID = 0;
  Project? openedProject;

  Widget buildProjectTiles (List<Project> projects, {bool completed = false}){
    return ListView.builder(
      //shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          child: Container(
            decoration: standardTile(15),
            margin: EdgeInsets.symmetric(horizontal: 20),
            child: ListTile(
              //dense: true,
              onTap: () {
                setState(() {
                  openedProject = project;
                });
              },
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    project.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 25,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // transfer to completed projects
                    }, 
                    icon: Icon(
                      completed ? Icons.check_box_outlined :
                      Icons.check_box_outline_blank,
                      color: Theme.of(context).colorScheme.onPrimary,
                    )
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  project.collaborators.isNotEmpty ? 
                    Text(
                      "Collaborators: ${project.collaborators}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),  
                    ) : Container(),
                  project.description.isNotEmpty ? 
                    Text(
                      project.description.isNotEmpty ?
                      "Description: ${project.description}" : "",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),    
                    ) : Container(),
                ],
              ),
            ),
          ),
        );
      } 
    );
  }

  @override
  Widget build(BuildContext context) {
    if (openedProject != null) {
      return ProjectDetails(
        project: openedProject!,
        onBack: () async {
          setState(() {
            openedProject = null;            
          });
        },
        onUpdate: (updatedProject) {
          setState(() {
            final idx = projects.indexWhere((p) => p.id == updatedProject.id);
            if (idx != -1) {
              projects[idx] = updatedProject;
              openedProject = updatedProject;
            }
          });
        },
      );
    }
    return Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: Container(
          color: Theme.of(context).colorScheme.primary,
          child: Column(
            children: [
              Container( // Tab Actions
                color: Theme.of(context).colorScheme.primary,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        margin: EdgeInsets.only(left: 40),
                        child: Text(
                          'Projects',
                          style: TextStyle(
                            fontSize: 28,
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.only(
                          right: 20
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.add,
                                color: Theme.of(context).colorScheme.onPrimary,
                                size: 30,
                              ),
                              onPressed: () {
                                setState((){
                                  addingProject = true;
                                });
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.search,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                              onPressed: () {
                                setState((){

                                });
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.more_vert,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                              onPressed: () {
                                setState((){

                                });
                              },
                            ),
                          ]
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (addingProject) ...[
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
                      onPressed: () {
                        setState(() {
                          projectTitle.clear();
                          addingProject = false;
                        });
                      },
                      icon: Icon(
                        Icons.close,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 20,
                      ),
                    ),
                    title: TextField(
                      controller: projectTitle,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      cursorColor: Theme.of(context).colorScheme.tertiary,
                      decoration: InputDecoration(
                        hintText: 'New Project',
                        labelText: 'New Project',
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
                        setState(() {
                          addingProject = false;
                          tempID += 1;
                          projects.add(
                            Project(
                              id: tempID,
                              title: projectTitle.text,
                              description: "", 
                              collaborators: [], 
                              toDoItems: []
                            )
                          );
                          projectTitle.clear();
                        });
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
                child: buildProjectTiles(projects)
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProjectDetails extends StatefulWidget {
  const ProjectDetails({super.key, required this.project, required this.onBack, required this.onUpdate});
  final Project project;
  final VoidCallback onBack;
  final ValueChanged<Project> onUpdate;
  @override
  State<ProjectDetails> createState() => _ProjectDetailsState();
}

class _ProjectDetailsState extends State<ProjectDetails> {
  late Project project = widget.project;
  bool expandDescription = true;
  bool editingDescription = false;
  bool expandCollaborators = true;
  bool editingCollaborators = false;
  bool expandToDo = true;
  bool editingToDo = false;
  bool openCompletedTasks = false;
  List<int> completedTasks = [];
  TextEditingController descriptionController = TextEditingController();
  TextEditingController textController = TextEditingController();
  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  int id = 0;
  @override
  void initState() {
    super.initState();
    descriptionController = TextEditingController(text: project.description);
  }

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }

  Widget singleFilterChip({
    required String label,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor:
            isSelected ? Colors.white.withAlpha(100) : Colors.transparent,
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

  Widget divLine() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8,horizontal: 10),
      height: 3,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            width: 1.25,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SingleChildScrollView(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Row( // Title and Back Button
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    margin: EdgeInsets.only(left: 10),
                    child: IconButton(
                      onPressed: widget.onBack, 
                      icon: Icon(
                        Icons.arrow_back,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 30,
                      ),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.only(left: 10,right: 20),
                    child: Text(
                      project.title,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimary
                      ),
                    ),
                  ),
                ],
              ),

              Container( // Description, To-Do, Collaborators
                decoration: standardTile(20),
                margin: EdgeInsets.symmetric(horizontal: 10,  vertical: 12),
                child: Container(
                  margin: EdgeInsets.all(5),
                  child: Column(
                    children: [
                      ListTile( // Description
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Description",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                            if(editingDescription) ...[
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      color:
                                          Theme.of(context).colorScheme.onPrimary,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        descriptionController.text = project.description;
                                        editingDescription = false;
                                      });
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.check,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        descriptionController.text = descriptionController.text.trim();
                                        project = Project(
                                          id: project.id,
                                          title: project.title,
                                          description: descriptionController.text,
                                          collaborators: project.collaborators,
                                          toDoItems: project.toDoItems,
                                        );
                                        editingDescription = false;
                                      });
                                      widget.onUpdate(project);
                                    },
                                  ),
                                ],
                              ),
                            ] 
                            else ...[
                              IconButton(
                                icon: Icon(
                                  Icons.edit,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                                onPressed: () {
                                  setState(() {
                                    editingDescription = true;
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                        subtitle: TextField(
                          controller: descriptionController,
                          maxLines: 5,
                          minLines: 1, 
                          readOnly: !editingDescription,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: "Write a description...",
                            hintStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSecondary,
                            ),
                            border: editingDescription ?
                              OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.onSecondary,
                                  width: 1.2,
                                ),
                              ) : InputBorder.none,
                            enabledBorder: editingDescription ? 
                              OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.onSecondary,
                                  width: 1.2,
                                ),
                              ) : InputBorder.none,
                            focusedBorder: editingDescription ?
                              OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.onSecondary,
                                  width: 1.2,
                                ),
                              ) : InputBorder.none,
                          ),
                        ),
                      ),
                      divLine(),
                      ListTile( // To-Do
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "To-do",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.add,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                              onPressed: () {
                                setState(() {
                                  openCompletedTasks = false;
                                  editingToDo = true;
                                });
                              },
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (editingToDo) ...[
                              Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 5,
                                ),
                                decoration: standardTile(10),
                                child: ListTile(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  title: SizedBox(
                                    child: Container(
                                      margin: EdgeInsets.symmetric(horizontal: 5),
                                      child: TextField(
                                        controller: textController,
                                        style: TextStyle(
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onPrimary,
                                        ),
                                        cursorColor:
                                            Theme.of(
                                              context,
                                            ).colorScheme.tertiary,
                                        decoration: InputDecoration(
                                          hintText: 'Details',
                                          labelText: 'Details*',
                                          labelStyle: TextStyle(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onSecondary,
                                          ),
                                          hintStyle: TextStyle(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onSecondary,
                                          ),
                                          border: const UnderlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  subtitle: Container(
                                    margin: EdgeInsets.only(top: 10),
                                    child: Column(
                                      children: [
                                        TextButton.icon(
                                          icon: Icon(
                                            Icons.calendar_today,
                                            size: 16,
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onPrimary,
                                          ),
                                          label: Text(
                                            selectedDate != null
                                                ? "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}"
                                                : "Pick date",
                                            style: TextStyle(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onPrimary,
                                              fontSize: 12,
                                            ),
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
                                          icon: Icon(
                                            Icons.access_time,
                                            size: 16,
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onPrimary,
                                          ),
                                          label: Text(
                                            selectedTime != null
                                                ? "${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}"
                                                : "Pick time",
                                            style: TextStyle(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onPrimary,
                                              fontSize: 12,
                                            ),
                                          ),
                                          onPressed: () async {
                                            final picked = await showTimePicker(
                                              context: context,
                                              initialTime:
                                                  selectedTime ??
                                                  TimeOfDay.now(),
                                              initialEntryMode:
                                                  TimePickerEntryMode.dial,
                                            );
                                            if (picked != null) {
                                              setState(() {
                                                selectedTime = picked;
                                              });
                                            }
                                          },
                                        ),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                                          children: [
                                            IconButton(
                                              alignment: Alignment.centerLeft,
                                              onPressed: () {
                                                setState(() {
                                                  textController.clear();
                                                  editingToDo = false;
                                                });
                                              },
                                              icon: Icon(
                                                Icons.close,
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.onPrimary,
                                                size: 20,
                                              ),
                                            ),
                                            IconButton(
                                              alignment: Alignment.centerRight,
                                              onPressed: () {
                                                if (textController.text.trim().isEmpty || selectedDate == null ||selectedTime == null) return;
                                                setState(() {
                                                  project.toDoItems.add(
                                                    ToDoItem(
                                                      text: textController.text.trim(),
                                                      id: id,
                                                      deadlineDate: DateTime(
                                                        selectedDate!.year,
                                                        selectedDate!.month,
                                                        selectedDate!.day,
                                                        selectedTime!.hour,
                                                        selectedTime!.minute,
                                                      ),
                                                    ),
                                                  );
                                                  widget.onUpdate(project);
                                                  textController.clear();
                                                  selectedDate = null;
                                                  selectedTime = null;
                                                  editingToDo = false;
                                                  id += 1;
                                                });
                                              },
                                              icon: Icon(
                                                Icons.check,
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.onPrimary,
                                                size: 20,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            if (project.toDoItems.isEmpty)
                              Container(
                                margin: EdgeInsets.symmetric(vertical: 10),
                                child: Text(
                                  "No tasks yet.",
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              )
                            else
                              ...project.toDoItems.map<Widget>((item) {
                                return Row(
                                  children: [
                                    Checkbox(
                                      value: completedTasks.contains(item.id),
                                      onChanged: (bool? changed) {
                                        setState(() {
                                          if (!completedTasks.contains(item.id)) {
                                            completedTasks.add(item.id);
                                          }
                                          else {
                                            completedTasks.remove(item.id);
                                          }
                                        });
                                      },
                                      activeColor:
                                          Theme.of(
                                            context,
                                          ).colorScheme.tertiary,
                                      checkColor:
                                          Theme.of(context).colorScheme.primary,
                                      side: BorderSide(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onPrimary,
                                        width: 1.5,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        item.text,
                                        style: TextStyle(
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onPrimary,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                          ],
                        ),
                      ),
                      divLine(),
                      ListTile(
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Collaborators",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.add,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                              onPressed: () {

                              },
                            ),
                          ],                         
                        ),
                        subtitle: project.collaborators.isEmpty ? 
                          Container(
                            margin: EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              "No collaborators",
                              style: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.onSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ) : 
                          Wrap(
                                  spacing: 8,
                                  children:
                                      project.collaborators.map((contact) {
                                        return ActionChip(
                                          label: Text(
                                            contact.name,
                                            style: TextStyle(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onPrimary,
                                            ),
                                          ),
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .secondary
                                              ,
                                          onPressed: () {
                                            // Optionally navigate to contact details
                                          },
                                        );
                                      }).toList(),
                                )
                      ),
                    ],
                  ),
                ),
              )
              
            ]
          ),
        ),
      ),
    );
  }
}


