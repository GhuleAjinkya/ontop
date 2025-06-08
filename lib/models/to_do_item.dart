class ToDoItem {
  final String id;
  String text;
  DateTime deadlineDate;
  DateTime? completedAt; // Track when the task was completed

  ToDoItem({
    required this.id,
    required this.text,
    required this.deadlineDate,
    this.completedAt,
  });
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
      completedAt:
          map['completed_at'] != null
              ? DateTime.parse(map['completed_at'])
              : null,
    );
  }
  // Convert ToDoItem to Map for MongoDB storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'deadline_date': deadlineDate.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  // Create a copy of ToDoItem with updated values
  ToDoItem copyWith({
    String? id,
    String? text,
    DateTime? deadlineDate,
    DateTime? completedAt,
  }) {
    return ToDoItem(
      id: id ?? this.id,
      text: text ?? this.text,
      deadlineDate: deadlineDate ?? this.deadlineDate,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
