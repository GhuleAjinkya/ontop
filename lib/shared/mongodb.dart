import 'package:mongo_dart/mongo_dart.dart';
import 'constants.dart';
// import 'dart:developer';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class MongoDatabase {
  static Db? _db;

  static bool get isConnected => _db?.isConnected ?? false;
  static connect() async {
    try {
      print("Connecting to MongoDB...");

      if (mongoURL.isEmpty) {
        print("ERROR: MongoDB URL is empty");
        return false;
      }

      print("Original MongoDB URL: $mongoURL");

      // Try to connect using the original URL first
      try {
        _db = await Db.create(mongoURL);
        await _db!.open();

        print(
          "MongoDB connection status: ${isConnected ? 'Connected' : 'Failed'}",
        );
        if (isConnected) {
          print("Successfully connected to MongoDB using original URL");
          print(
            "Documents: ${await _db!.collection(collectionName).find().toList()}",
          );
          return true;
        }
      } catch (originalError) {
        print("Original connection failed: $originalError");

        // Close any partially opened connection
        try {
          await _db?.close();
        } catch (e) {
          // Ignore close errors
        }
        _db = null;
      }

      // Try alternative connection approach for mongodb+srv scheme
      print("Trying alternative connection method...");

      // Parse the mongodb+srv URL manually
      final uri = Uri.parse(mongoURL);
      final host = uri.host;
      final userInfo = uri.userInfo.split(':');
      final username = userInfo[0];
      final password = userInfo.length > 1 ? userInfo[1] : '';
      final database = uri.path.replaceFirst('/', '');
      // final queryParams = uri.query;

      // Create alternative connection strings to try
      final List<String> alternativeUrls = [
        // Try with cluster0-shard-00-00 (typical MongoDB Atlas shard)
        "mongodb://$username:$password@cluster0-shard-00-00.weacgri.mongodb.net:27017/$database?ssl=true&replicaSet=atlas-12ocqf-shard-0&authSource=admin&retryWrites=true&w=majority",

        // Try with the original host but different protocol
        "mongodb://$username:$password@$host:27017/$database?ssl=true&authSource=admin&retryWrites=true&w=majority",

        // Try without SSL for testing
        "mongodb://$username:$password@$host:27017/$database?authSource=admin&retryWrites=true&w=majority",
      ];

      for (String altUrl in alternativeUrls) {
        try {
          print(
            "Trying connection with: ${altUrl.replaceAll(password, '***')}",
          );
          _db = await Db.create(altUrl);
          await _db!.open();

          if (isConnected) {
            print("Successfully connected using alternative URL");
            print(
              "Documents: ${await _db!.collection(collectionName).find().toList()}",
            );
            return true;
          }
        } catch (altError) {
          print("Alternative connection failed: $altError");
          try {
            await _db?.close();
          } catch (e) {
            // Ignore close errors
          }
          _db = null;
        }
      }

      print("All connection attempts failed");
      return false;
    } catch (e) {
      print("Unexpected error in MongoDB connection: $e");
      return false;
    }
  }

  static disconnect() async {
    if (isConnected) {
      await _db!.close();
      print("MongoDB disconnected");
    }
  }

  static Future<bool> insertData(
    Map<String, dynamic> data, {
    String? userId,
    String type = 'contact',
  }) async {
    if (!isConnected) await connect();

    try {
      if (userId == null) {
        print("Error: No userId provided for insertData");
        return false;
      }

      // Only add starred field for contacts (default to 0 if not provided)
      if (type == 'contact' && !data.containsKey('starred')) {
        data['starred'] = 0;
      }

      // Add type field to the document to identify what kind of data it is
      data['type'] = type;

      // Use the user's specific collection
      var userCollection = _db!.collection(userId);
      await userCollection.insertOne(data);
      print(
        "Document of type '$type' inserted successfully into user collection $userId",
      );
      print("Inserted data: $data");
      return true;
    } catch (e) {
      print("Error inserting document: $e");
      return false;
    }
  }

  static Future<bool> insertMany(
    List<Map<String, dynamic>> dataList, {
    String? userId,
    String type = 'contact',
  }) async {
    if (!isConnected) await connect();

    try {
      if (userId == null) {
        print("Error: No userId provided for insertMany");
        return false;
      }

      // Only add starred field for contacts and add type field for each item
      for (var data in dataList) {
        // Only add starred field for contacts (default to 0 if not provided)
        if (type == 'contact' && !data.containsKey('starred')) {
          data['starred'] = 0;
        }
        // Add type field to each document
        data['type'] = type;
      }

      // Use the user's specific collection
      var userCollection = _db!.collection(userId);
      // ignore: unused_local_variable
      var result = await userCollection.insertMany(dataList);
      print(
        "${dataList.length} documents of type '$type' inserted successfully into user collection $userId",
      );
      print("Inserted data: $dataList");
      return true;
    } catch (e) {
      print("Error inserting multiple documents: $e");
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getContacts({
    String? userId,
    String? type,
  }) async {
    if (!isConnected) await connect();

    try {
      if (userId == null) {
        print(
          "Warning: No userId provided for getContacts, returning empty list",
        );
        return [];
      }

      // Use the user's specific collection instead of the shared contacts collection
      var userCollection = _db!.collection(userId);

      // If type is provided, filter documents by type
      var query = type != null ? where.eq('type', type) : where;
      var docs = await userCollection.find(query).toList();

      String typeMsg = type != null ? " of type '$type'" : "";
      print(
        "Retrieved ${docs.length} documents$typeMsg from user collection $userId",
      );
      return docs;
    } catch (e) {
      print("Error retrieving documents from MongoDB: $e");
      return [];
    }
  }

  static Future<bool> updateData(
    Map<String, dynamic> data, {
    String? userId,
    String? type,
  }) async {
    if (!isConnected) await connect();

    try {
      if (userId == null) {
        print("Error: No userId provided for updateData");
        return false;
      }

      // Use the user's specific collection
      var userCollection = _db!.collection(userId);

      // Ensure we have the _id to identify the document to update
      if (!data.containsKey('_id')) {
        print("Error updating document: No _id provided");
        return false;
      }

      var id = data['_id'];

      // Remove _id from data to update since it's used for the query
      var updateData = Map<String, dynamic>.from(data);
      updateData.remove('_id');

      // If type is provided, set it in the update data
      if (type != null) {
        updateData['type'] = type;
      }

      // First, check if the document already has a type field
      var existingDoc = await userCollection.findOne(where.eq('_id', id));

      // If the document exists and has a type but no type parameter was provided, preserve the existing type
      if (existingDoc != null &&
          existingDoc.containsKey('type') &&
          type == null) {
        // Don't modify the existing type
      } else if (type == null) {
        // If no type exists and none was provided, default to 'contact'
        updateData['type'] = 'contact';
      }

      // Build the query with just the _id (no need for userId filter since we're using user-specific collection)
      var query = where.eq('_id', id);

      // Use updateOne with filters
      var result = await userCollection.updateOne(query, {'\$set': updateData});

      if (result.isSuccess) {
        print("Document updated successfully in user collection $userId");
        print("Updated data: $updateData for document with _id: $id");
        return true;
      } else {
        print("Failed to update document. Modified: ${result.nModified}");
        return false;
      }
    } catch (e) {
      print("Error updating document: $e");
      return false;
    }
  }

  static Future<bool> deleteData(dynamic id, {String? userId}) async {
    if (!isConnected) await connect();

    try {
      if (userId == null) {
        print("Error: No userId provided for deleteData");
        return false;
      }

      // Use the user's specific collection
      var userCollection = _db!.collection(userId);

      // Handle both ObjectId and string IDs
      dynamic queryId = id;
      if (id is String) {
        // Try to convert string to ObjectId if it looks like an ObjectId
        if (ObjectId.isValidHexId(id)) {
          try {
            queryId = ObjectId.fromHexString(id);
          } catch (e) {
            // If conversion fails, keep it as string
            queryId = id;
          }
        }
        // Otherwise keep it as string (for imported contacts with custom string IDs)
      }

      // Build the query with just the _id (no need for userId filter since we're using user-specific collection)
      var query = where.eq('_id', queryId);

      // Use deleteOne with filters
      var result = await userCollection.deleteOne(query);

      if (result.isSuccess) {
        print("Document deleted successfully from user collection $userId");
        print("Deleted document with _id: $queryId");
        return true;
      } else {
        print("Failed to delete document. Deleted: ${result.nRemoved}");
        return false;
      }
    } catch (e) {
      print("Error deleting document: $e");
      return false;
    }
  }

  // Delete data by custom query fields (for tasks)
  static Future<bool> deleteDataByQuery(
    Map<String, dynamic> query, {
    String? userId,
  }) async {
    if (!isConnected) await connect();

    try {
      if (userId == null) {
        print("Error: No userId provided for deleteDataByQuery");
        return false;
      }

      // Use the user's specific collection
      var userCollection = _db!.collection(userId);

      // Build the MongoDB query
      var mongoQuery = where;
      query.forEach((key, value) {
        mongoQuery = mongoQuery.eq(key, value);
      });

      // Use deleteMany to delete all matching documents
      var result = await userCollection.deleteMany(mongoQuery);

      if (result.isSuccess) {
        print("Documents deleted successfully from user collection $userId");
        print("Deleted ${result.nRemoved} documents matching query: $query");
        return true;
      } else {
        print("Failed to delete documents. Deleted: ${result.nRemoved}");
        return false;
      }
    } catch (e) {
      print("Error deleting documents by query: $e");
      return false;
    }
  }

  // Update data by custom query fields (for tasks)
  static Future<bool> updateDataByQuery(
    Map<String, dynamic> query,
    Map<String, dynamic> updateData, {
    String? userId,
    String? type,
  }) async {
    if (!isConnected) await connect();

    try {
      if (userId == null) {
        print("Error: No userId provided for updateDataByQuery");
        return false;
      }

      // Use the user's specific collection
      var userCollection = _db!.collection(userId);

      // If type is provided, set it in the update data
      if (type != null) {
        updateData['type'] = type;
      }

      // Build the mongo query
      var mongoQuery = where;
      for (var entry in query.entries) {
        mongoQuery = mongoQuery.eq(entry.key, entry.value);
      }

      // Use updateOne with filters
      var result = await userCollection.updateOne(mongoQuery, {
        '\$set': updateData,
      });

      if (result.isSuccess) {
        print("Document updated successfully in user collection $userId");
        print("Updated data: $updateData with query: $query");
        return true;
      } else {
        print("Failed to update document. Modified: ${result.nModified}");
        return false;
      }
    } catch (e) {
      print("Error updating document by query: $e");
      return false;
    }
  }

  // Helper method to hash passwords
  static String _hashPassword(String password) {
    var bytes = utf8.encode(password); // Convert password to bytes
    var digest = sha256.convert(bytes); // Hash using SHA-256
    return digest.toString();
  }

  // Helper method to get the next user ID sequence (e.g., user_001, user_002)
  static Future<String> _getNextUserId() async {
    if (!isConnected) await connect();

    try {
      // Get the counter collection
      var counterCollection = _db!.collection(counterCollectionName);

      // Try to find an existing counter document
      var counterDoc = await counterCollection.findOne({'_id': 'userId'});

      int sequenceValue = 1;

      if (counterDoc != null) {
        // If counter exists, increment it
        var result = await counterCollection.findAndModify(
          query: {'_id': 'userId'},
          update: {
            '\$inc': {'seq': 1},
          },
          returnNew: true,
        );

        sequenceValue = result?['seq'] ?? 1;
      } else {
        // If no counter exists, create one starting at 1
        await counterCollection.insertOne({'_id': 'userId', 'seq': 1});
      }

      // Format the user ID with leading zeros (e.g., user_001)
      String formattedId = sequenceValue.toString().padLeft(3, '0');
      return '$userIdPrefix$formattedId';
    } catch (e) {
      print("Error generating next user ID: $e");
      // Fallback to timestamp-based ID to ensure uniqueness
      return '$userIdPrefix${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // Method to create a user-specific collection
  static Future<bool> _createUserCollection(String userId) async {
    if (!isConnected) await connect();

    try {
      // Create a new collection for the user
      await _db!.createCollection(userId);
      print("Created new collection for user: $userId");

      // Add an index on the 'starred' field for faster contact queries
      // This index will only be useful for contact documents, but won't hurt other document types
      var userCollection = _db!.collection(userId);
      await userCollection.createIndex(keys: {'starred': 1});

      // Add an index on the 'type' field for faster filtering by document type
      await userCollection.createIndex(keys: {'type': 1});

      return true;
    } catch (e) {
      print("Error creating user collection: $e");
      return false;
    }
  }

  // Get a user-specific collection
  static DbCollection? getUserCollection(String userId) {
    if (!isConnected) return null;

    try {
      return _db!.collection(userId);
    } catch (e) {
      print("Error getting user collection: $e");
      return null;
    }
  }

  // User registration method
  static Future<Map<String, dynamic>> registerUser(
    Map<String, dynamic> userData,
  ) async {
    if (!isConnected) await connect();

    try {
      // Check if user already exists (by email or phone number)
      var usersCollection = _db!.collection(userCollectionName);

      var existingUserByEmail = await usersCollection.findOne(
        where.eq('email', userData['email']),
      );

      var existingUserByPhone = await usersCollection.findOne(
        where.eq('number', userData['number']),
      );

      if (existingUserByEmail != null) {
        return {'success': false, 'message': 'Email is already registered'};
      }

      if (existingUserByPhone != null) {
        return {
          'success': false,
          'message': 'Phone number is already registered',
        };
      }

      // Generate a new sequential user ID (e.g., user_001)
      String userId = await _getNextUserId();

      // Hash password before storing
      String hashedPassword = _hashPassword(userData['password']);

      // Prepare user data
      var userToInsert = {
        '_id': userId,
        'name': userData['name'],
        'email': userData['email'],
        'number': userData['number'],
        'password': hashedPassword,
        'created_at': DateTime.now(),
      };

      // Insert the user
      await usersCollection.insertOne(userToInsert);
      print(
        "User registered successfully: ${userData['email']} with ID: $userId",
      );

      // Create a user-specific collection for their data
      await _createUserCollection(userId);

      return {
        'success': true,
        'message': 'Registration successful',
        'user':
            userToInsert
              ..remove('password'), // Remove password before returning
      };
    } catch (e) {
      print("Error registering user: $e");
      return {
        'success': false,
        'message': 'Registration failed. Please try again.',
      };
    }
  }

  // User login method
  static Future<Map<String, dynamic>> loginUser({
    required String phoneNumber,
    required String password,
  }) async {
    if (!isConnected) await connect();

    try {
      var usersCollection = _db!.collection(userCollectionName);

      // Hash the password for comparison
      String hashedPassword = _hashPassword(password);

      // Find user by phone number and password
      var user = await usersCollection.findOne(
        where
            .eq('number', phoneNumber)
            .and(where.eq('password', hashedPassword)),
      );

      if (user == null) {
        return {
          'success': false,
          'message': 'Invalid phone number or password',
        };
      }

      // Remove sensitive information before returning
      user.remove('password');

      String userId = user['_id'];
      // Verify that the user's collection exists, create it if not
      // This is a safety check in case the collection wasn't created during registration
      if (userId.startsWith(userIdPrefix)) {
        try {
          var collections = await _db!.getCollectionNames();
          if (!collections.contains(userId)) {
            await _createUserCollection(userId);
            print("Created missing collection for user: $userId during login");
          }
        } catch (e) {
          print("Error checking/creating user collection during login: $e");
        }
      }

      print("User logged in successfully: ${user['email']} with ID: $userId");
      return {'success': true, 'message': 'Login successful', 'user': user};
    } catch (e) {
      print("Error during login: $e");
      return {'success': false, 'message': 'Login failed. Please try again.'};
    }
  }

  // Verify if user exists by email
  static Future<bool> userExistsByEmail(String email) async {
    if (!isConnected) await connect();

    try {
      var usersCollection = _db!.collection(userCollectionName);
      var user = await usersCollection.findOne(where.eq('email', email));
      return user != null;
    } catch (e) {
      print("Error checking user by email: $e");
      return false;
    }
  }

  // Verify if user exists by phone number
  static Future<bool> userExistsByPhone(String phoneNumber) async {
    if (!isConnected) await connect();

    try {
      var usersCollection = _db!.collection(userCollectionName);
      var user = await usersCollection.findOne(where.eq('number', phoneNumber));
      return user != null;
    } catch (e) {
      print("Error checking user by phone: $e");
      return false;
    }
  }

  // TODO remove these specific methods and rely on updateData or create similirly specfic methods for other fields
  // Toggle contact star status
  static Future<bool> toggleStarContact(
    dynamic contactId,
    bool starred, {
    String? userId,
  }) async {
    if (!isConnected) await connect();

    try {
      if (userId == null) {
        print("Error: No userId provided for toggleStarContact");
        return false;
      }

      // Use the user's specific collection
      var userCollection = _db!.collection(userId);

      // Handle both ObjectId and string IDs
      dynamic queryId = contactId;
      if (contactId is String) {
        // Try to convert string to ObjectId if it looks like an ObjectId
        if (ObjectId.isValidHexId(contactId)) {
          try {
            queryId = ObjectId.fromHexString(contactId);
          } catch (e) {
            // If conversion fails, keep it as string
            queryId = contactId;
          }
        }
        // Otherwise keep it as string (for imported contacts with custom string IDs)
      }

      // Build query to find the contact by ID
      var query = where.eq('_id', queryId);

      // Update the starred field
      var updateData = {'starred': starred ? 1 : 0};

      var result = await userCollection.updateOne(query, {'\$set': updateData});

      if (result.isSuccess && result.nModified > 0) {
        print(
          "Contact star status updated successfully in user collection $userId",
        );
        return true;
      } else {
        print(
          "Failed to update contact star status. Modified: ${result.nModified}",
        );
        return false;
      }
    } catch (e) {
      print("Error updating contact star status: $e");
      return false;
    }
  }

  // Method to update user password
  static Future<bool> updateUserPassword(
    String userId,
    String newPasswordHash,
  ) async {
    if (!isConnected) await connect();

    try {
      var usersCollection = _db!.collection(userCollectionName);

      // Update the password field for the specific user
      var result = await usersCollection.updateOne(where.eq('_id', userId), {
        '\$set': {'password': newPasswordHash},
      });

      if (result.isSuccess && result.nModified > 0) {
        print("Password updated successfully for user: $userId");
        return true;
      } else {
        print("Failed to update password. User not found or no changes made.");
        return false;
      }
    } catch (e) {
      print("Error updating user password: $e");
      return false;
    }
  }
}
