class BusStops {
  final double lat;
  final double lng;
  final String name;

  BusStops({
    required this.lat,
    required this.lng,
    required this.name,
  });

  factory BusStops.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'];
    final location = geometry['location'];
    return BusStops(
      lat: location['lat'] as double,
      lng: location['lng'] as double,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'lat': lat,
      'lng': lng,
      'name': name,
    };
    return data;
  }
}
