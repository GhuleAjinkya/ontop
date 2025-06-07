class ToDoItem {
  final String id;
  String text;
  DateTime deadlineDate;

  ToDoItem({required this.id, required this.text, required this.deadlineDate});

  // Convert Map to ToDoItem object
  factory ToDoItem.fromMap(Map<String, dynamic> map) {
    return ToDoItem(
      id:
          map['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      text: map['text'] ?? '',
      deadlineDate:
          map['deadline_date'] != null
              ? DateTime.parse(map['deadline_date'])
              : DateTime.now(),
    );
  }

  // Convert ToDoItem to Map for MongoDB storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'deadline_date': deadlineDate.toIso8601String(),
    };
  }

  // Create a copy of ToDoItem with updated values
  ToDoItem copyWith({String? id, String? text, DateTime? deadlineDate}) {
    return ToDoItem(
      id: id ?? this.id,
      text: text ?? this.text,
      deadlineDate: deadlineDate ?? this.deadlineDate,
    );
  }
}
