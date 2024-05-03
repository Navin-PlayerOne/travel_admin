import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:travel_admin/auth/auth.dart';
import 'package:travel_admin/constants/constants.dart';
import 'package:travel_admin/models/busstopdb.dart';
import 'package:travel_admin/models/model.dart';

class DatabaseAPI {
  static DatabaseAPI? _instance;
  Client client = Client();
  late final Account account;
  late final Databases databases;
  final AuthAPI auth = AuthAPI();
  late String userId = "";

  factory DatabaseAPI() {
    _instance ??= DatabaseAPI._internal();
    return _instance!;
  }

  DatabaseAPI._internal() {
    init();
  }

  init() {
    client
        .setEndpoint(APPWRITE_URL)
        .setProject(APPWRITE_PROJECT_ID)
        .setSelfSigned();
    account = Account(client);
    databases = Databases(client);
    getUserId();
  }

  getUserId() async {
    if (userId != null) {
      await account.get().then((value) => userId = value.$id);
    }
  }

  //for admin

  Future<Document> addBusStop({required BusStopDB busStopDB}) async {
    await getUserId();
    Document doc = await addBusStopMetaData(busStopDB: busStopDB);
    //admin collection
    return updateUserCurrentTrip(doc);
  }

  Future<Document> updateUserCurrentTrip(doc) async {
    late Document existingDocument;
    // Check if the document exists
    try {
      existingDocument = await databases.getDocument(
          collectionId: COLLECTION_ADMIN,
          databaseId: APPWRITE_DATABASE_ID,
          documentId: userId);
    } catch (e) {
      // Create a new document
      return databases.createDocument(
          databaseId: APPWRITE_DATABASE_ID,
          collectionId: COLLECTION_ADMIN,
          documentId: userId,
          data: {'currentTravel': doc.$id});
    }

    if (existingDocument != null) {
      // Update the existing document
      return databases.updateDocument(
          databaseId: APPWRITE_DATABASE_ID,
          collectionId: COLLECTION_ADMIN,
          documentId: userId,
          data: {'currentTravel': doc.$id});
    } else {
      // Create a new document
      return databases.createDocument(
          databaseId: APPWRITE_DATABASE_ID,
          collectionId: COLLECTION_ADMIN,
          documentId: userId,
          data: {'currentTravel': doc.$id});
    }
  }

  Future<Document> addBusStopMetaData({required BusStopDB busStopDB}) async {
    //return Travel_info doc id
    Document doc = await addBusStopRawData(busStopDB: busStopDB);
    return databases.createDocument(
        databaseId: APPWRITE_DATABASE_ID,
        collectionId: COLLECTION_TRAVEL_INFO,
        documentId: ID.unique(),
        data: {
          'busStopDB_ID': doc.$id,
          'CurrentLocationCoordinates':
              busStopDB.currentLocationCoordinates.toJson().toString(),
          'progress': 0,
          'fromName': busStopDB.fromName,
          'toName': busStopDB.toName,
          'passengerCount': 0,
          'currentBusStopIndex': 0
        });
  }

  Future<Document> addTravelInfoDynamic(BusStopDB busStopDB) async {
    //return Travel_info doc id
    return databases.createDocument(
        databaseId: APPWRITE_DATABASE_ID,
        collectionId: COLLECTION_TRAVEL_INFO,
        documentId: ID.unique(),
        data: {
          'busStopDB_ID': busStopDB.id,
          'CurrentLocationCoordinates':
              busStopDB.currentLocationCoordinates.toJson().toString(),
          'progress': 0,
          'fromName': busStopDB.fromName,
          'toName': busStopDB.toName,
          'passengerCount': 0,
          'currentBusStopIndex': 0
        });
  }

  Future<Document> addBusStopRawData({required BusStopDB busStopDB}) {
    //returns BusStopRawData doc id
    return databases.createDocument(
        databaseId: APPWRITE_DATABASE_ID,
        collectionId: COLLECTION_BUSSTOPS,
        documentId: ID.unique(),
        data: busStopDB.toJson());
  }

  Future<String?> getCurrentTrip() async {
    try {
      await getUserId();
      Document doc = await databases.getDocument(
          collectionId: COLLECTION_ADMIN,
          databaseId: APPWRITE_DATABASE_ID,
          documentId: userId);
      if (doc != null) {
        print(doc.data['currentTravel']);
        return doc.data['currentTravel'];
      } else {
        return null;
      }
    } catch (e) {
      print(e);
      return null;
    }
  }

  Future<TripTemplate?> fetchTripInfo(String tripId) async {
    //travel Info
    Document doc = await databases.getDocument(
        collectionId: COLLECTION_TRAVEL_INFO,
        databaseId: APPWRITE_DATABASE_ID,
        documentId: tripId);
    if (doc != null) {
      Document doc2 = await databases.getDocument(
          collectionId: COLLECTION_BUSSTOPS,
          databaseId: APPWRITE_DATABASE_ID,
          documentId: doc.data['busStopDB_ID']);

      print(doc.data['fromName']);
      print(doc.data['toName']);
      Map<String, dynamic> fr, to;
      fr = convertJsonString(doc2.data['From']);
      to = convertJsonString(doc2.data['To']);
      return TripTemplate(
          fromName: doc.data['fromName'],
          toName: doc.data['toName'],
          from: LatLng(double.parse(fr['lat']), double.parse(fr['lng'])),
          to: LatLng(double.parse(to['lat']), double.parse(to['lng'])));
    } else {
      return null;
    }
  }

  Future<String> getCurrentLocationCoordinates(String tripId) async {
    //travel Info
    Document doc = await databases.getDocument(
        collectionId: COLLECTION_TRAVEL_INFO,
        databaseId: APPWRITE_DATABASE_ID,
        documentId: tripId);
    if (doc != null) {
      return doc.data['CurrentLocationCoordinates'];
    } else {
      return "";
    }
  }

  Future<int> getCurrentPassengerCount(String tripId) async {
    //travel Info
    Document doc = await databases.getDocument(
        collectionId: COLLECTION_TRAVEL_INFO,
        databaseId: APPWRITE_DATABASE_ID,
        documentId: tripId);
    if (doc != null) {
      return doc.data['passengerCount'];
    } else {
      return 0;
    }
  }

  Future updateCurrentLocationCoordinated(
      LatLng currentLocation, String tripId) async {
    print("Updating Your current location ....");
    print(currentLocation.latitude.toString());
    print(currentLocation.longitude.toString());
    Document doc = await databases.updateDocument(
        collectionId: COLLECTION_TRAVEL_INFO,
        databaseId: APPWRITE_DATABASE_ID,
        documentId: tripId,
        data: {
          'CurrentLocationCoordinates':
              [currentLocation.latitude, currentLocation.longitude].toString()
        });
  }

  Future getBusStopDB(String from, String to) async {
    try {
      final document = await databases.listDocuments(
        databaseId: APPWRITE_DATABASE_ID,
        collectionId: COLLECTION_BUSSTOPS,
        queries: [
          Query.equal('From', from),
          Query.equal('To', to),
        ],
      );
      print("loading from appwrite this busStops ALready Exist!");
      print(document.documents.first.data);
      print(document.documents.first.data['BusStopList']);
      if (document.documents.isNotEmpty) {
        Map<String, dynamic> tempJson, json = {};
        tempJson = document.documents.first.data;
        tempJson.forEach((key, value) {
          print("===========");
          print(key);
          print(value);
          print("===========");
          if (key != 'BusStopList') {
            json.addEntries({key: convertJsonString(value.toString())}.entries);
          } else {
            json.addEntries(
                {key: value.map((e) => convertJsonString(e)).toList()}.entries);
          }
        });
        print("corrected json object");
        print(json);
        BusStopDB busStopDB = BusStopDB.fromAppWrite(json);
        busStopDB.id = document.documents.first.$id;
        return busStopDB;
      } else {
        return null;
      }
      print("---");
    } catch (e) {
      print("Errorrr");
      print(e);
      return null;
    }
  }

  dynamic convertJsonString(String name) {
    try {
      List<String> str =
          name.replaceAll("{", "").replaceAll("}", "").split(",");
      Map<String, dynamic> result = {};
      for (int i = 0; i < str.length; i++) {
        List<String> s = str[i].split(":");
        result.putIfAbsent(s[0].trim(), () => s[1].trim());
      }
      return result;
    } catch (e) {
      return name;
    }
  }

  Future updatePassengerCount(String tripId, int passengerCount) async {
    try {
      // Update the document with the new data
      Document document = await databases.updateDocument(
        collectionId: COLLECTION_TRAVEL_INFO,
        databaseId: APPWRITE_DATABASE_ID,
        documentId: tripId,
        data: {'passengerCount': passengerCount},
      );

      print('Document updated successfully: ${document.data}');
    } catch (e) {
      print('Failed to update Passenger Count: $e');
    }
  }

  Future updateBusStopIndex(String tripId, int busStopIndex) async {
    try {
      // Update the document with the new data
      Document document = await databases.updateDocument(
        collectionId: COLLECTION_TRAVEL_INFO,
        databaseId: APPWRITE_DATABASE_ID,
        documentId: tripId,
        data: {'currentBusStopIndex': busStopIndex},
      );

      print('Document updated successfully: ${document.data}');
    } catch (e) {
      print('Failed to update currentBusStopIndex : $e');
    }
  }
}
