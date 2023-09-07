import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:travel_admin/models/model.dart';

Future<List<BusStops>> searchNearbyRestaurants(lat, lng) async {
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
