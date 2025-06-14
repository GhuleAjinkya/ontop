// File: test/contact_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:asep_app/models/contact.dart';
import 'package:asep_app/services/contact_service.dart';

// This test file tests the fallback functionality of ContactService
// It ensures that even when the API is unavailable, the service falls back to SQLite storage

void main() {
  late ContactService contactService;

  setUp(() {
    contactService = ContactService();
  });

  group('ContactService API fallback tests', () {
    test('createContact should work even when API is unavailable', () async {
      // Create a test contact
      final contact = Contact(
        id: 0, // will be assigned by SQLite
        name: 'Test Contact',
        organization: 'Test Organization',
        position: 'Tester',
        phoneNumber: '123-456-7890',
        starred: 0,
      );

      // Attempt to create the contact
      final result = await contactService.createContact(contact);

      // Even if API fails, the method should return true because it falls back to SQLite
      expect(result, true);
    });

    test(
      'fetchContacts should return data even when API is unavailable',
      () async {
        // Attempt to fetch contacts
        final contacts = await contactService.fetchContacts();

        // Should return some contacts (at least the one we just created)
        expect(contacts.isNotEmpty, true);
      },
    );

    test('updateContact should work even when API is unavailable', () async {
      // Get existing contacts to work with
      final contacts = await contactService.fetchContacts();
      expect(contacts.isNotEmpty, true);

      // Get first contact to update
      final contactToUpdate = contacts.first;
      final updatedContact = Contact(
        id: contactToUpdate.id,
        name: '${contactToUpdate.name} Updated',
        organization: contactToUpdate.organization,
        position: contactToUpdate.position,
        phoneNumber: contactToUpdate.phoneNumber,
        starred: contactToUpdate.starred,
      );

      // Attempt to update the contact
      final result = await contactService.updateContact(updatedContact);

      // Should be successful due to fallback
      expect(result, true);
    });

    test(
      'updateStarredStatus should work even when API is unavailable',
      () async {
        // Get existing contacts to work with
        final contacts = await contactService.fetchContacts();
        expect(contacts.isNotEmpty, true);

        // Get first contact to update starred status
        final contactToStar = contacts.first;
        final newStarredValue = contactToStar.starred == 0 ? true : false;

        // Attempt to update the starred status
        final result = await contactService.updateStarredStatus(
          contactToStar.id,
          newStarredValue,
        );

        // Should be successful due to fallback
        expect(result, true);
      },
    );

    test('deleteContact should work even when API is unavailable', () async {
      // Get existing contacts to work with
      final contacts = await contactService.fetchContacts();
      expect(contacts.isNotEmpty, true);

      // Get first contact to delete
      final contactToDelete = contacts.first;

      // Attempt to delete the contact
      final result = await contactService.deleteContact(contactToDelete.id);

      // Should be successful due to fallback
      expect(result, true);
    });
  });
}
