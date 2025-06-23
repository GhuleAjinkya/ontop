import 'dart:convert';
import 'package:http/http.dart' as http;
import 'client.dart';

const String baseUrl = 'http://10.0.2.2:3000/clients'; // use 10.0.2.2 for Android emulator, localhost for browser

class ClientService {
  Future<List<Client>> fetchClients() async {
    final response = await http.get(Uri.parse(baseUrl));
    if (response.statusCode == 200) {
      List jsonData = json.decode(response.body);
      return jsonData.map((e) => Client.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load clients');
    }
  }

  Future<Client> addClient(Client client) async {
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(client.toJson()),
    );
    if (response.statusCode == 200) {
      return Client.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to add client');
    }
  }

  Future<void> updateClient(Client client) async {
    final response = await http.put(
      Uri.parse('$baseUrl/${client.id}'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(client.toJson()),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update client');
    }
  }

  Future<void> deleteClient(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/$id'));
    if (response.statusCode != 204) {
      throw Exception('Failed to delete client');
    }
  }
}
