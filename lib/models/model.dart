class BusStops {
  final double lat;
  final double lng;
  final String name;
  final int distance;
  final int duration;

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

  TripTemplate({required this.fromName, required this.toName});
}
