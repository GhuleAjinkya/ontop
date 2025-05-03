import 'package:mongo_dart/mongo_dart.dart';
import 'package:logging/logging.dart';

class MongoDatabase {
  static late Db _db;
  static late DbCollection contactCollection;
  static final _logger = Logger('MongoDatabase');
  static bool _initialized = false;

  static Future<void> connect() async {
    if (!_initialized) {
      const String connectionString = "mongodb://localhost:27017/ontop";
      _db = await Db.create(connectionString);
      await _db.open();
      contactCollection = _db.collection('clients');
      _initialized = true;
      _logger.info('✅ MongoDB connected');
    }
  }

  static Future<void> disconnect() async {
    if (_initialized) {
      await _db.close();
      _initialized = false;
      _logger.info('MongoDB disconnected');
    }
  }

  static DbCollection getContactCollection() {
    if (!_initialized) {
      throw StateError('MongoDB not initialized. Call connect() first.');
    }
    return contactCollection;
  }
}
