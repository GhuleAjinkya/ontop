import 'contact.dart';
import 'to_do_item.dart';

class Project {
  final int id;
  String title;
  String description;
  List<Contact> collaborators;
  List<ToDoItem> toDoItems;

  Project({
    required this.id,
    required this.title,
    required this.description,
    required this.collaborators,
    required this.toDoItems
  });
}