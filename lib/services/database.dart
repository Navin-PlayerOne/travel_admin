import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:travel_admin/auth/auth.dart';
import 'package:travel_admin/constants/constants.dart';
import 'package:travel_admin/models/busstopdb.dart';

class DatabaseAPI {
  Client client = Client();
  late final Account account;
  late final Databases databases;
  final AuthAPI auth = AuthAPI();

  DatabaseAPI() {
    init();
  }

  init() {
    client
        .setEndpoint(APPWRITE_URL)
        .setProject(APPWRITE_PROJECT_ID)
        .setSelfSigned();
    account = Account(client);
    databases = Databases(client);
  }

  Future<Document> addBusStop({required BusStopDB busStopDB}) {
    return databases.createDocument(
        databaseId: APPWRITE_DATABASE_ID,
        collectionId: COLLECTION_BUSSTOPS,
        documentId: ID.unique(),
        data: busStopDB.toJson()
      );
  }
}