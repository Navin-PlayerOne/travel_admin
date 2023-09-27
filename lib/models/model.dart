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
        duration: 0
        );
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
