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

// Constants
const double earthRadius = 6378137; // Earth's radius in meters
const double pi = 3.14159265359; // Pi value

// Function to calculate latitude bounds
List<double> calculateBounds(double latitude) {
  // Distance offsets in meters
  final double upperOffset = 500; // Positive for upward change
  final double lowerOffset = -500; // Negative for downward change

  final double latUp = upperOffset / earthRadius;
  final double latDown = lowerOffset / earthRadius;

  final double latUpper = latitude + (latUp * 180) / pi;
  final double latLower = latitude + (latDown * 180) / pi;

  return [latUpper, latLower];
}

// Function to generate polygon points around the route
List<Map<String, double>> generatePolygonPoints(List<LatLng> polylinePoints) {
  List<Map<String, double>> upperBound = [];
  List<Map<String, double>> lowerBound = [];

  for (LatLng point in polylinePoints) {
    final List<double> bounds = calculateBounds(point.latitude);

    upperBound.add({'lat': bounds[0], 'lng': point.longitude});
    lowerBound.add({'lat': bounds[1], 'lng': point.longitude});
  }

  // Reverse lower bound to correct position
  List<Map<String, double>> reverseBound = List.from(lowerBound.reversed);

  // Combine upper and reversed lower bounds
  List<Map<String, double>> fullPoly = upperBound + reverseBound;

  return fullPoly;
}

//return wether the busstop is present inside the polygon or not
bool isBusStopInsideRange(List<LatLng> polygonCoordinates, LatLng point) {
  int crossings = 0;
  final int numberOfVertices = polygonCoordinates.length;

  for (int i = 0; i < numberOfVertices; i++) {
    final LatLng vertex1 = polygonCoordinates[i];
    final LatLng vertex2 = polygonCoordinates[(i + 1) % numberOfVertices];

    if (vertex1.longitude == vertex2.longitude &&
        vertex1.longitude == point.longitude) {
      // The point is on an edge of the polygon
      if ((vertex1.latitude <= point.latitude &&
              point.latitude <= vertex2.latitude) ||
          (vertex1.latitude >= point.latitude &&
              point.latitude >= vertex2.latitude)) {
        return true; // The point is on the polygon boundary
      }
    }

    if (vertex1.latitude > point.latitude &&
        vertex2.latitude > point.latitude) {
      continue; // Skip this pair of vertices
    }

    if (vertex1.latitude < point.latitude &&
        vertex2.latitude < point.latitude) {
      continue; // Skip this pair of vertices
    }

    // Check if the ray intersects with the edge (latitude comparison)
    final double x = (point.latitude - vertex1.latitude) *
            (vertex2.longitude - vertex1.longitude) /
            (vertex2.latitude - vertex1.latitude) +
        vertex1.longitude;

    if (x < point.longitude) {
      crossings++;
    }
  }

  // If the number of crossings is odd, the point is inside the polygon
  return crossings % 2 == 1;
}

void findDistance(LatLng sourceLocation, List<BusStops> waypoints) async {
  final apiKey = 'YOUR_API_KEY';
  final apiUrl = 'https://maps.googleapis.com/maps/api/distancematrix/json';

  final destinations = waypoints
      .map((e) => '${e.lat},${e.lng}')
      .join('|'); // Combine waypoints into a single string
  final sourceLoc = "${sourceLocation.latitude},${sourceLocation.longitude}";
  final url =
      '$apiUrl?origins=$sourceLoc&destinations=$destinations&key=$apiKey';

  print(url);

  final response = await http.get(
    Uri.parse(url),
  );

  if (response.statusCode == 200) {
    final data = json.decode(response.body);

    if (data['status'] == 'OK') {
      print(data);
      final rows = data['rows'][0]['elements'];

      for (int i = 0; i < waypoints.length; i++) {
        print(
            "))))))))))))))))))))))))))))))))))000000000000000000000000000000))))))))))))))))))))");
        //print(rows[i]);
        final distanceText = rows[i]['distance']['text'];
        final durationText = rows[i]['duration']['text'];
        final destination = waypoints[i].name;

        print('Distance from source to $destination: $distanceText');
        print('Duration from source to $destination: $durationText');
      }
    } else {
      print('>Error: ${data['status']}');
    }
  } else {
    print('Failed to fetch distance matrix data');
  }
}
