import 'contacts_adapter.dart';

// Helper method to update a contact via adapter
Future<bool> updateContactViaAdapter(Map<String, dynamic> contactData) async {
  try {
    return await ContactsAdapter.updateContact(contactData);
  } catch (e) {
    print("Error in adapter.updateContact: $e");
    return false;
  }
}

// Helper method to toggle contact star status via adapter
Future<bool> toggleStarViaAdapter(dynamic contactId, bool starred) async {
  try {
    return await ContactsAdapter.toggleStarContact(contactId, starred);
  } catch (e) {
    print("Error in adapter.toggleStarContact: $e");
    return false;
  }
}
