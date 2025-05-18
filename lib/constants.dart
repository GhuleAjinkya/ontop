import 'package:flutter_dotenv/flutter_dotenv.dart';

// Get MongoDB URL from environment variables - REQUIRED
String getMongoURL() {
  final url = dotenv.env['MONGO_URI'];
  if (url == null) {
    throw Exception(
      'MONGO_URI not found in environment variables. Create .env file from .env.template',
    );
  }
  return url;
}

final mongoURL = getMongoURL();
const collectionName = "contacts";
const userCollectionName = "users";
const userIdPrefix = "user_";
const counterCollectionName = "counters";
