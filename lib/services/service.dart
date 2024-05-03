import 'dart:convert';
import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:travel_admin/models/model.dart';
import 'package:travel_admin/services/database.dart';

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

Future<List<BusStops>> findDistanceAndDuration(
    LatLng sourceLocation, List<BusStops> busStops) async {
  final apiKey = 'YOUR_API_KEY';
  List<BusStops> updatedBusStops = [];

  for (int i = 0; i < busStops.length; i++) {
    BusStops busStop = busStops[i];
    String apiUrl =
        'https://maps.googleapis.com/maps/api/distancematrix/json?origins=${sourceLocation.latitude},${sourceLocation.longitude}&destinations=${busStop.lat},${busStop.lng}&key=$apiKey';

    // Make the API request
    final response = await http.get(Uri.parse(apiUrl));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);

      // Check if the API request was successful
      if (data['status'] == 'OK') {
        final List<dynamic> elements = data['rows'][0]['elements'];

        // Check if the API returned valid distance and duration
        if (elements.isNotEmpty && elements[0]['status'] == 'OK') {
          int distance = elements[0]['distance']['value'];
          int duration = elements[0]['duration']['value'];

          // Update the bus stop with distance and duration
          BusStops updatedBusStop = BusStops(
            lat: busStop.lat,
            lng: busStop.lng,
            name: busStop.name,
            distance: distance,
            duration: duration,
          );

          updatedBusStops.add(updatedBusStop);
        }
      }
    }

    // Introduce a delay to avoid frequent API requests
    await Future.delayed(Duration(milliseconds: 300));
  }

  return updatedBusStops;
}

List<BusStops> removeDuplicates(List<BusStops> busStopsList) {
  List<BusStops> uniqueBusStops = [];
  Set<String> uniqueKeys = {};

  for (var busStop in busStopsList) {
    String key = '${busStop.lat}_${busStop.lng}';

    // Check if the key is not in the set (i.e., not encountered before)
    if (!uniqueKeys.contains(key)) {
      uniqueKeys.add(key);
      uniqueBusStops.add(busStop);
    }
  }

  return uniqueBusStops;
}

class LocationUpdater {
  LatLng? _previousLocation;

  // Function to calculate the Haversine distance
  double haversineDistance(LatLng location1, LatLng location2) {
    const R = 6371000.0; // Radius of the Earth in meters
    final lat1Rad = _degreesToRadians(location1.latitude);
    final lon1Rad = _degreesToRadians(location1.longitude);
    final lat2Rad = _degreesToRadians(location2.latitude);
    final lon2Rad = _degreesToRadians(location2.longitude);

    final dLat = lat2Rad - lat1Rad;
    final dLon = lon2Rad - lon1Rad;

    final a = pow(sin(dLat / 2), 2) +
        cos(lat1Rad) * cos(lat2Rad) * pow(sin(dLon / 2), 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }

  // Function to convert degrees to radians
  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  // Function to update location and check distance threshold
  void updateLocation(LatLng newLocation, tripId) {
    if (_previousLocation != null) {
      final distance = haversineDistance(_previousLocation!, newLocation);
      final threshold = 5; // Threshold distance in meters

      if (distance >= threshold) {
        // Update the database with the new location
        _updateDatabase(newLocation, tripId);
        _previousLocation = newLocation;
      }
    } else {
      _previousLocation = newLocation;
    }
  }

//function to  update the db
  void _updateDatabase(LatLng newLocation, tripId) {
    print('Updating database with new location: $newLocation');
    DatabaseAPI().updateCurrentLocationCoordinated(newLocation, tripId);
  }
}

class ProximityToBusStops {
  int findNearestBusStopIndex(LatLng currentLocation,
      List<BusStops> busStopLocations, double threshold) {
    for (int i = 0; i < busStopLocations.length; i++) {
      double distance = calculateDistance(currentLocation,
          LatLng(busStopLocations[i].lat, busStopLocations[i].lng));
      if (distance <= threshold) {
        return i;
      }
    }
    return -1; // No nearby bus stop within the threshold
  }

  double calculateDistance(LatLng location1, LatLng location2) {
    const earthRadius = 6371000; // Radius of the Earth in meters
    var lat1 = location1.latitude * pi / 180;
    var lon1 = location1.longitude * pi / 180;
    var lat2 = location2.latitude * pi / 180;
    var lon2 = location2.longitude * pi / 180;
    var dLat = lat2 - lat1;
    var dLon = lon2 - lon1;
    var a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    var c = 2 * atan2(sqrt(a), sqrt(1 - a));
    var distance = earthRadius * c;
    return distance;
  }
}

class BusDistance {
  LatLng currentLocation = LatLng(0, 0); // Initialize with default location
  final double threshold = 2; // Threshold distance in meters
  LatLng? previousLocation;

  // Method to update the bus's current location
  int updateLocation(LatLng newLocation, List<BusStops> busStopLocations) {
    if (shouldUpdateLocation(newLocation)) {
      currentLocation = newLocation;
      return checkProximityToBusStop(busStopLocations);
    }
    return -1;
  }

  // Method to check if the location should be updated
  bool shouldUpdateLocation(LatLng newLocation) {
    if (previousLocation == null) {
      // First time updating location
      previousLocation = newLocation;
      return true;
    }

    // Calculate distance between current and previous location
    double distance =
        ProximityToBusStops().calculateDistance(newLocation, previousLocation!);

    // Update previous location if significant distance change
    if (distance >= 2) {
      previousLocation = newLocation;
      return true;
    }

    return false; // Do not update location if distance change is insignificant
  }

  // Method to check proximity to bus stops when the bus's location changes
  int checkProximityToBusStop(List<BusStops> busStopLocations) {
    ProximityToBusStops proximity = ProximityToBusStops();

    int nearestBusStopIndex = proximity.findNearestBusStopIndex(
        currentLocation, busStopLocations, threshold);

    if (nearestBusStopIndex != -1) {
      print(
          'Index of Nearest Bus Stop within $threshold meters: $nearestBusStopIndex');
    } else {
      print('No nearby bus stop within $threshold meters.');
    }
    return nearestBusStopIndex;
  }
}
