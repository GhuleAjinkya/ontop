class Contact {
  final dynamic id; // Can be ObjectId or its string representation
  final String name;
  final String organization;
  final String position;
  final String phoneNumber;
  final String email; // Add email field
  final String notes; // Add notes field
  int starred;
  // TODO make starred bool
  Contact({
    required this.id,
    required this.name,
    required this.organization,
    required this.phoneNumber,
    required this.position,
    required this.starred,
    this.email = '', // Make email optional with default empty string
    this.notes = '', // Make notes optional with default empty string
  }); // Convert MongoDB document to Contact object
  factory Contact.fromMongo(Map<String, dynamic> doc) {
    return Contact(
      id: doc['_id'], // Keep as ObjectId
      name: doc['name'] ?? '',
      organization: doc['organization'] ?? '',
      phoneNumber: doc['phoneNumber'] ?? '',
      position: doc['position'] ?? '',
      email: doc['email'] ?? '', // Add email field
      notes: doc['notes'] ?? '', // Add notes field
      starred: doc['starred'] ?? 0,
    );
  } // Create a copy of Contact with updated values
  Contact copyWith({
    dynamic id,
    String? name,
    String? organization,
    String? position,
    String? phoneNumber,
    String? email,
    String? notes,
    int? starred,
  }) {
    return Contact(
      id: id ?? this.id,
      name: name ?? this.name,
      organization: organization ?? this.organization,
      position: position ?? this.position,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      starred: starred ?? this.starred,
    );
  }

  // Convert Contact to Map for MongoDB
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'organization': organization,
      'phoneNumber': phoneNumber,
      'position': position,
      'email': email,
      'notes': notes,
      'starred': starred,
      'type': 'contact', // Add type field
    };
  }
}