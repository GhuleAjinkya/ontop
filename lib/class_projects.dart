import 'package:flutter/material.dart';
import 'models/project.dart';
import 'main.dart';

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
        }  
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
  const ProjectDetails({super.key, required this.project, required this.onBack});
  final Project project;
  final VoidCallback onBack;
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
              Container(
                decoration: standardTile(20),
                margin: EdgeInsets.symmetric(horizontal: 10,  vertical: 12),
                child: Container(
                  margin: EdgeInsets.all(5),
                  child: Column(
                    children: [
                      
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