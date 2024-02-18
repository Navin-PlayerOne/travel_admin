import 'package:google_maps_flutter/google_maps_flutter.dart';

class BusStops {
  final double lat;
  final double lng;
  final String name;
  final int distance;
  final int duration;

  // Override equality and hashCode based on lat and lng
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BusStops &&
          runtimeType == other.runtimeType &&
          lat == other.lat &&
          lng == other.lng &&
          name == other.name &&
          distance == other.distance &&
          duration == other.duration;

  @override
  int get hashCode =>
      lat.hashCode ^
      lng.hashCode ^
      name.hashCode ^
      distance.hashCode ^
      duration.hashCode;

  BusStops(
      {required this.lat,
      required this.lng,
      required this.name,
      required this.distance,
      required this.duration});

  factory BusStops.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'];
    final location = geometry['location'];
    return BusStops(
        lat: location['lat'] as double,
        lng: location['lng'] as double,
        name: json['name'] as String,
        distance: 0,
        duration: 0);
  }

  factory BusStops.fromAppWrite(Map<String, dynamic> json) {
    print("------ busStop Appwrite json");
    print(json);
    return BusStops(
        lat: double.parse(json['lat']),
        lng: double.parse(json['lng']),
        name: json['name'],
        distance: int.parse(json['distance']),
        duration: int.parse(json['duration']));
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'lat': lat,
      'lng': lng,
      'name': name,
      'duration': duration,
      'distance': distance
    };
    return data;
  }
}

class TripTemplate {
  String fromName;
  String toName;
  LatLng from;
  LatLng to;
  late String tripId;

  TripTemplate(
      {required this.fromName,
      required this.toName,
      required this.from,
      required this.to});
}
