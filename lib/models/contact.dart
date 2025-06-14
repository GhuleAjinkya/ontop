import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

// Main Contact class used throughout the application
class Contact {
  final int id;
  final String name;
  final String organization;
  final String position;
  final String phoneNumber;
  final String email;
  final String notes;
  int starred;

  Contact({
    required this.id,
    required this.name,
    required this.organization,
    required this.phoneNumber,
    required this.position,
    required this.starred,
    this.email = '',
    this.notes = '',
  });
}

class ApiContact {
  final String? id;
  final String name;
  final String phoneNumber;
  final String position;
  final String organization;
  final String email;
  final String notes;
  final String type; // Always "contact"
  final bool starred;
  final DateTime? createdAt;

  ApiContact({
    this.id,
    required this.name,
    required this.phoneNumber,
    required this.position,
    required this.organization,
    this.email = '',
    this.notes = '',
    this.type = 'contact',
    this.starred = false,
    this.createdAt,
  });
  factory ApiContact.fromJson(Map<String, dynamic> json) {
    return ApiContact(
      id:
          json['_id'] is ObjectId
              ? json['_id'].toHexString()
              : json['_id']?.toString(),
      name: json['name'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      position: json['position'] ?? '',
      organization: json['organization'] ?? '',
      email: json['email'] ?? '',
      notes: json['notes'] ?? '',
      type: json['type'] ?? 'contact',
      starred: json['starred'] == true || json['starred'] == 1,
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : null,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'position': position,
      'organization': organization,
      'email': email,
      'notes': notes,
      'type': type,
      'starred': starred,
    };
  }

  // Convert from local Contact to ApiContact
  factory ApiContact.fromContact(Contact contact) {
    return ApiContact(
      name: contact.name,
      phoneNumber: contact.phoneNumber,
      position: contact.position,
      organization: contact.organization,
      email: contact.email,
      notes: contact.notes,
      starred: contact.starred == 1,
    );
  }
  // Convert to local Contact (with dummy id if none exists)
  Contact toContact() {
    return Contact(
      id: -1, // This will be replaced when saved to local DB
      name: name,
      phoneNumber: phoneNumber,
      position: position,
      organization: organization,
      email: email,
      notes: notes,
      starred: starred ? 1 : 0,
    );
  }
}
