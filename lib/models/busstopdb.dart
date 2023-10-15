import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:travel_admin/models/model.dart';

class BusStopDB {
  LatLng from;
  LatLng to;
  List<BusStops> busStopList;
  LatLng currentLocationCoordinates;
  String polyLineString;
  int distance;
  int duration;
  late String fromName;
  late String toName;

  BusStopDB(
      {required this.from,
      required this.to,
      required this.busStopList,
      required this.currentLocationCoordinates,
      required this.distance,
      required this.duration,
      required this.polyLineString});

  factory BusStopDB.fromJson(Map<String, dynamic> json) {
    final List<dynamic> busStopListJson = json['BusStopList'];
    final List<BusStops> busStopList = busStopListJson
        .map((busStopJson) => BusStops.fromJson(busStopJson))
        .toList();

    return BusStopDB(
        from: json['From'],
        to: json['To'],
        busStopList: busStopList,
        currentLocationCoordinates: json['CurrentLocationCoordinates'],
        distance: json['distance'],
        duration: json['duration'],
        polyLineString: json['polyLineString']);
  }

  factory BusStopDB.fromAppWrite(Map<String, dynamic> json) {
    print("------ busStopDb Appwrite json");
    print(json);
    return BusStopDB(
        from: LatLng(double.parse(json['From']['lat']),
            double.parse(json['From']['lng'])),
        to: LatLng(
            double.parse(json['To']['lat']), double.parse(json['To']['lng'])),
        busStopList: List<BusStops>.from(
          json['BusStopList'].map((e) => BusStops.fromAppWrite(e)),
        ),
        currentLocationCoordinates: LatLng(0, 0),
        distance: int.parse(json['distance']),
        duration: int.parse(json['duration']),
        polyLineString: json['polyLineString']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'From': {'lat': from.latitude, 'lng': from.longitude}.toString(),
      'To': {'lat': to.latitude, 'lng': to.longitude}.toString(),
      'BusStopList':
          busStopList.map((busStop) => busStop.toJson().toString()).toList(),
      // 'CurrentLocationCoordinates': {'lat': currentLocationCoordinates.latitude,'lng': currentLocationCoordinates.longitude}.toString(),
      'polyLineString': polyLineString,
      'distance': distance,
      'duration': duration
    };
    return data;
  }
}
