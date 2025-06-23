import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

class Event {
  final ObjectId? id;
  final String title;
  final String description;
  final DateTime dateTime;
  final String userId;
  final DateTime createdAt;

  Event({
    this.id,
    required this.title,
    required this.description,
    required this.dateTime,
    required this.userId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'title': title,
      'description': description,
      'dateTime': dateTime.toIso8601String(),
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'type': 'event',
    };
  }

  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id:
          map['_id'] is ObjectId
              ? map['_id']
              : (map['_id'] != null
                  ? ObjectId.fromHexString(map['_id'].toString())
                  : null),
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      dateTime:
          map['dateTime'] is String
              ? DateTime.parse(map['dateTime'])
              : (map['dateTime'] as DateTime? ?? DateTime.now()),
      userId: map['userId'] ?? '',
      createdAt:
          map['createdAt'] is String
              ? DateTime.parse(map['createdAt'])
              : (map['createdAt'] as DateTime? ?? DateTime.now()),
    );
  }
}
