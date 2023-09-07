import 'dart:convert';
import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:travel_admin/models/model.dart';

Future<List<BusStops>> searchNearbyBusStops(lat, lng) async {
  final apiKey = 'YOUR_API_KEY';
  final radius = 2000;
  final keyword = 'bus stop';
  final type = "transit_station";

  final url = 'https://maps.googleapis.com/maps/api/place/textsearch/json?'
      'query=$keyword'
      '&location=$lat,$lng'
      '&radius=$radius'
      '&key=$apiKey';

  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    final jsonMap = json.decode(response.body);
    final results = jsonMap['results'] as List<dynamic>;

    final List<BusStops> busStopsList = results.map((result) {
      return BusStops.fromJson(result);
    }).toList();

    // Print the extracted data for verification
    for (var busStop in busStopsList) {
      print('Name: ${busStop.name}');
      print('Latitude: ${busStop.lat}');
      print('Longitude: ${busStop.lng}');
    }
    return busStopsList;
  } else {
    throw Exception('Failed to load bus_stations');
  }
}

// Function to check if a bus stop is on the polyline
bool isBusStopOnPolyline(LatLng busStop, List<LatLng> polyline) {
  for (int i = 0; i < polyline.length - 1; i++) {
    final LatLng point1 = polyline[i];
    final LatLng point2 = polyline[i + 1];

    // Check if the bus stop is on the line segment between point1 and point2
    if (busStop.latitude >= min(point1.latitude, point2.latitude) &&
        busStop.latitude <= max(point1.latitude, point2.latitude) &&
        busStop.longitude >= min(point1.longitude, point2.longitude) &&
        busStop.longitude <= max(point1.longitude, point2.longitude)) {
      return true;
    }
  }
  return false;
}
