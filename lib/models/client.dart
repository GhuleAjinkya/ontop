class Client {
  final String id;
  final String name;
  final String phone;
  final String position;
  final String organization;

  Client({required this.id, required this.name, required this.phone, required this.position, required this.organization});

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['_id'],
      name: json['name'],
      phone: json['phone'],
      position: json['position'],
      organization: json['organization'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'position': position,
      'organization': organization,
    };
  }
}
