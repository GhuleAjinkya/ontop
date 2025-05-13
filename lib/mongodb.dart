import 'package:mongo_dart/mongo_dart.dart';
import 'constants.dart';
import 'dart:developer';

class MongoDatabase {
  static Db? _db;

  static bool get isConnected => _db?.isConnected ?? false;

  static connect() async {
    try {
      print("Connecting to MongoDB...");

      // Create MongoDB connection using parseUri to properly handle mongodb+srv schema
      // This converts mongodb+srv:// to standard mongodb:// with correct configuration
      _db = await Db.create(mongoURL);
      await _db!.open();

      print(
        "MongoDB connection status: ${isConnected ? 'Connected' : 'Failed'}",
      );
      if (isConnected) {
        inspect(_db);
        print(
          "Documents: ${await _db!.collection(collectionName).find().toList()}",
        );
        return true;
      }
      return false;
    } catch (e) {
      print("MongoDB error: $e");

      // Try alternative connection approach if mongodb+srv scheme is not supported
      try {
        print("Trying alternative connection method...");
        // Extract host and credentials from the connection string
        final uri = Uri.parse(
          mongoURL.replaceFirst('mongodb+srv://', 'https://'),
        );
        final host = uri.host;
        final userInfo = uri.userInfo.split(':');
        final username = userInfo[0];
        final password = userInfo.length > 1 ? userInfo[1] : '';
        final database = uri.path.replaceAll('/', '');

        // Create a direct connection to MongoDB Atlas using standard mongodb:// protocol
        final directUrl =
            "mongodb://$username:$password@$host:27017/$database?retryWrites=true&w=majority";
        print("Connecting with: $directUrl");

        _db = await Db.create(directUrl);
        await _db!.open();

        print(
          "Alternative connection status: ${isConnected ? 'Connected' : 'Failed'}",
        );
        if (isConnected) {
          inspect(_db);
          print(
            "Documents: ${await _db!.collection(collectionName).find().toList()}",
          );
          return true;
        }
      } catch (innerError) {
        print("Alternative connection also failed: $innerError");
      }

      return false;
    }
  }

  static disconnect() async {
    if (isConnected) {
      await _db!.close();
      print("MongoDB disconnected");
    }
  }

  static Future<bool> insertData(Map<String, dynamic> data) async {
    if (!isConnected) await connect();

    try {
      var collection = _db!.collection(collectionName);
      await collection.insertOne(data);
      print("Document inserted successfully");
      print("Inserted data: $data");
      return true;
    } catch (e) {
      print("Error inserting document: $e");
      return false;
    }
  }

  static Future<bool> insertMany(List<Map<String, dynamic>> dataList) async {
    if (!isConnected) await connect();

    try {
      var collection = _db!.collection(collectionName);
      // ignore: unused_local_variable
      var result = await collection.insertMany(dataList);
      print("${dataList.length} documents inserted successfully");
      print("Inserted data: $dataList");
      return true;
    } catch (e) {
      print("Error inserting multiple documents: $e");
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getContacts() async {
    if (!isConnected) await connect();

    try {
      var collection = _db!.collection(collectionName);
      var docs = await collection.find().toList();
      print("Retrieved ${docs.length} contacts from MongoDB");
      return docs;
    } catch (e) {
      print("Error retrieving contacts from MongoDB: $e");
      return [];
    }
  }

  static Future<bool> updateData(Map<String, dynamic> data) async {
    if (!isConnected) await connect();

    try {
      var collection = _db!.collection(collectionName);
      
      // Ensure we have the _id to identify the document to update
      if (!data.containsKey('_id')) {
        print("Error updating document: No _id provided");
        return false;
      }
      
      var id = data['_id'];
      
      // Remove _id from data to update since it's used for the query
      var updateData = Map<String, dynamic>.from(data);
      updateData.remove('_id');
      
      // Use updateOne with a filter by _id
      var result = await collection.updateOne(
        where.eq('_id', id),
        {
          '\$set': updateData
        },
      );
      
      if (result.isSuccess) {
        print("Document updated successfully");
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

  static Future<bool> deleteData(ObjectId id) async {
    if (!isConnected) await connect();

    try {
      var collection = _db!.collection(collectionName);
      
      // Use deleteOne with a filter by _id
      var result = await collection.deleteOne(where.eq('_id', id));
      
      if (result.isSuccess) {
        print("Document deleted successfully");
        print("Deleted document with _id: $id");
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
}
