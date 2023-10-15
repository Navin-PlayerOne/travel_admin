import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:travel_admin/models/busstopdb.dart';
import 'package:travel_admin/models/model.dart';
import 'package:travel_admin/services/database.dart';
import 'package:travel_admin/services/service.dart';

class Trip extends StatefulWidget {
  const Trip({super.key});

  @override
  State<Trip> createState() => _TripState();
}

class _TripState extends State<Trip> {
  bool isFirst = false;
  @override
  void initState() {
    super.initState();
    isFirst = true;
  }

  Set<Marker> busStopMarkers = {};
  final Completer<GoogleMapController> _controller = Completer();
  late LatLng sourceLocation;
  late LatLng destination;
  late List<BusStops> finalBusStopList = [];
  late int distance;
  late int minutes;
  late String routePolyLine;
  late String fromName;
  late String toName;
  Map<String, dynamic> hashes = {};

  List<LatLng> polylineCoordinates = [];
  List<LatLng> polygonCoordinates = [];
  LocationData? currentLocation;
  bool completed = false;

  void getCurrentLocation() async {
    Location location = Location();
    location.getLocation().then((location) {
      currentLocation = location;
      setState(() {});
    });

    GoogleMapController googleMapController = await _controller.future;

    // location.onLocationChanged.listen((newLocation) {
    //   currentLocation = newLocation;

    //   googleMapController.animateCamera(CameraUpdate.newCameraPosition(
    //       CameraPosition(
    //           zoom: 13.5,
    //           target: LatLng(newLocation.latitude!, newLocation.longitude!))));
    //   setState(() {});
    // });
  }

  void getPolyLinePoints() async {
    PolylinePoints polylinePoints = PolylinePoints();
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        'YOUR_API_KEY',
        PointLatLng(sourceLocation.latitude, sourceLocation.longitude),
        PointLatLng(destination.latitude, destination.longitude));

    if (result.points.isNotEmpty) {
      result.points.forEach((PointLatLng point) =>
          {polylineCoordinates.add(LatLng(point.latitude, point.longitude))});
    }

    print("polypoints results ?????????????????");
    print(result.distance);
    print(result.distanceText);
    print(result.distanceValue);
    print(result.duration);
    print(result.durationText);
    print(result.durationValue);
    print(result.overviewPolyline);

    distance = result.distanceValue ?? 0;
    minutes = result.durationValue ?? 0;
    routePolyLine = result.overviewPolyline ?? '';

    polylinePoints.decodePolyline(result.overviewPolyline!).forEach((element) {
      print("----");
      print(element.latitude);
      print(element.longitude);
    });
    //creating a polygon
    // Create a polygon with extra width
    // Generate polygon points
    try {
      List<Map<String, double>> polygonPoints =
          generatePolygonPoints(polylineCoordinates);

      // Print the polygon points
      for (Map<String, double> point in polygonPoints) {
        polygonCoordinates.add(LatLng(point['lat']!, point['lng']!));
      }
    } catch (e) {
      print(e);
    }
    setState(() {
      completed = true;
    });

    //get bus stops
    List<BusStops> busStops = [];
    for (int i = 0; i < polylineCoordinates.length; i += 50) {
      print(
          ".......................................................iteration ${i + 1}................................................................");
      busStops.addAll(await searchNearbyBusStops(
          polylineCoordinates[i].latitude, polylineCoordinates[i].longitude));
    }
    // Clear existing bus stop markers
    busStopMarkers.clear();
    for (int i = 0; i < busStops.length; i++) {
      final BusStops busStop = busStops[i];
      final LatLng busStopLatLng = LatLng(busStop.lat, busStop.lng);

      // Check if the bus stop is on the polyline
      if (isBusStopInsideRange(polygonCoordinates, busStopLatLng)) {
        finalBusStopList.add(busStop);
        busStopMarkers.add(
          Marker(
            markerId: MarkerId('busStop_$i'), // Unique marker ID
            position: busStopLatLng,
            infoWindow: InfoWindow(
              title: 'Bus Stop',
              snippet: busStop.name,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue,
            ),
          ),
        );
      }
    }
    polylineCoordinates.forEach((element) {
      print("${element.latitude} ++++ ${element.longitude}");
    });
    print("--------------+++++++++++++++------------------");
    print(polylineCoordinates.length);
    setState(() {});

    //updating the time and distance in the final busstop
    finalBusStopList =
        await findDistanceAndDuration(sourceLocation, finalBusStopList);

    //sort the busStop based on the distance
    finalBusStopList.sort((a, b) => a.distance.compareTo(b.distance));

    print("BusStopList final!");
    finalBusStopList.forEach((element) {
      print("${element.name} ${element.distance}");
    });

    BusStopDB busStopDB = BusStopDB(
        from: sourceLocation,
        to: destination,
        busStopList: finalBusStopList,
        currentLocationCoordinates: LatLng((currentLocation?.latitude) ?? 0.0,
            currentLocation?.longitude ?? 0.0),
        distance: distance,
        duration: minutes,
        polyLineString: routePolyLine);
    busStopDB.fromName = fromName;
    busStopDB.toName = toName;

    print(busStopDB);
    print("iiiiiiiiiiiiiiiiiiiiiiiiiiiiiii");
    print(busStopDB.toJson());
    print("9999999999999999999999999999999999");
    print(busStopDB.busStopList);

    DatabaseAPI api = DatabaseAPI();
    api.addBusStop(busStopDB: busStopDB).then((value) {
      print("BusStops Added to DB");
      print(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    hashes = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    sourceLocation =
        LatLng(hashes['source'].latitude, hashes['source'].longitude);
    destination = LatLng(hashes['dest'].latitude, hashes['dest'].longitude);
    fromName = hashes['fromName'];
    toName = hashes['toName'];
    if (isFirst) {
      print("welcome");
      getPolyLinePoints();
      getCurrentLocation();
      isFirst = false;
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text("Trip"),
      ),
      body: currentLocation == null || !completed
          ? const Center(
              child: SpinKitSquareCircle(
                size: 200,
                color: Colors.indigo,
              ),
            )
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                  target: LatLng(
                      sourceLocation!.latitude!, sourceLocation!.longitude!),
                  zoom: 13.5),
              markers: {
                Marker(
                    markerId: const MarkerId('source'),
                    position: sourceLocation),
                Marker(
                    markerId: const MarkerId('destination'),
                    position: destination),
                Marker(
                    markerId: const MarkerId('currentLocation'),
                    position: LatLng(currentLocation!.latitude!,
                        currentLocation!.longitude!)),
                ...busStopMarkers,
              },
              polylines: {
                Polyline(
                    polylineId: const PolylineId('route'),
                    points: polylineCoordinates,
                    color: Theme.of(context).primaryColor,
                    width: 6),
              },
              polygons: {
                Polygon(
                  polygonId: const PolygonId('border_polygon'),
                  points: polygonCoordinates,
                  fillColor: Colors.transparent,
                  strokeColor: Colors.blue,
                  strokeWidth: 2,
                ),
              },
              onMapCreated: (controller) {
                _controller.complete(controller);
              },
            ),
    );
  }
}
