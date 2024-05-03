import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appwrite/models.dart';
import 'package:cool_alert/cool_alert.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
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
  late DatabaseAPI db;
  HttpServer? _server;

  @override
  void initState() {
    super.initState();
    isFirst = true;
    db = DatabaseAPI();
    startServer(); // Start the server when the page lands
  }

  @override
  void dispose() {
    stopServer(); // Stop the server when the page is exited
    super.dispose();
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
  late String currentTripId;
  Map<String, dynamic> hashes = {};
  bool fromContinue = false;
  int currentPassengerCount = 0;
  final locationUpdater = LocationUpdater();
  BusDistance busDistance = BusDistance();

  List<LatLng> polylineCoordinates = [];
  List<LatLng> polygonCoordinates = [];
  LocationData? currentLocation;
  bool completed = false;
  bool isLargeDistance = false;

  late BitmapDescriptor sourceIcon;
  late BitmapDescriptor destinationIcon;
  late BitmapDescriptor currentLocationIcon;

  Future getCurrentLocation() async {
    print("fetching current location");
    Location location = Location();
    location.getLocation().then((location) {
      currentLocation = location;
      setState(() {});
      print("got your current location");
    });

    GoogleMapController googleMapController = await _controller.future;

    location.onLocationChanged.listen((newLocation) {
      if (completed) {
        int currentBusStoIndex = busDistance.updateLocation(
            LatLng(newLocation!.latitude!, newLocation!.longitude!),
            finalBusStopList);
        if (currentBusStoIndex != -1) {
          print("updating the bustop index to the appwrite db ...");
          db.updateBusStopIndex(currentTripId, currentBusStoIndex);
        }
      }
      currentLocation = newLocation;
      locationUpdater.updateLocation(
          LatLng(newLocation.latitude!, newLocation.longitude!), currentTripId);

      googleMapController.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(
              zoom: 13.5,
              target: LatLng(newLocation.latitude!, newLocation.longitude!))));
      setState(() {});
    });
  }

  Future getPolyLinePoints() async {
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

    try {
      if (result.distanceValue! > 25000) {
        isLargeDistance = true;
        return;
      }
    } catch (e) {
      return;
    }

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

    //remove duplicates
    finalBusStopList = removeDuplicates(finalBusStopList);

    setState(() {
      completed = true;
    });

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
        polyLineString: routePolyLine,
        currentBusStopIndex: 0);
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
    fromContinue = hashes['fromContinue'] ?? false;
    if (isFirst) {
      isFirst = false;
      print("welcome");
      tryCaching();
    }
    return Scaffold(
      appBar: AppBar(
        title: Text("Trip", style: GoogleFonts.poppins(fontSize: 25)),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
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
                  position: LatLng(
                      currentLocation!.latitude!, currentLocation!.longitude!),
                ),
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
                  strokeColor: Colors.transparent,
                  strokeWidth: 2,
                ),
              },
              onMapCreated: (controller) {
                _controller.complete(controller);
              },
            ),
      floatingActionButton: Visibility(
        visible: completed,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 8, 8, 8),
          child: Row(
            children: [
              FloatingActionButton(
                  onPressed: () =>
                      updatePassengerCount(currentPassengerCount += 1),
                  child: const Icon(Icons.add)),
              SizedBox(
                width: 16,
              ),
              FloatingActionButton(
                  onPressed: () =>
                      updatePassengerCount(currentPassengerCount -= 1),
                  child: const Icon(Icons.remove)),
            ],
          ),
        ),
      ),
    );
  }

  updatePassengerCount(int count) async {
    if (count < 0) {
      currentPassengerCount = 0;
    } else {
      db.updatePassengerCount(await db.getCurrentTrip() ?? '', count);
    }
  }

  void tryCaching() async {
    final result = await db.getBusStopDB(
        {'lat': sourceLocation.latitude, 'lng': sourceLocation.longitude}
            .toString(),
        {'lat': destination!.latitude, 'lng': destination!.longitude}
            .toString());
    if (result != null) {
      print("result is not null so proceeding..");
      getCurrentLocation();
      // currentTripId = (await db.getCurrentTrip())!;
      setProperties(result);
      //db.updateUserCurrentTrip(currentTripId);
    } else {
      print("New data so loading it from google !!!!!!!!!!!!!!");
      getCurrentLocation();
      print(result);
      await getPolyLinePoints();
      if (isLargeDistance) {
        CoolAlert.show(
          context: context,
          type: CoolAlertType.error,
          text: "Trip must be within 25 KM",
          barrierDismissible: false,
          onConfirmBtnTap: () => Navigator.pop(context),
        );
      }
    }
  }

  void setCustomMarkers() {
    BitmapDescriptor.fromAssetImage(ImageConfiguration.empty, "")
        .then((icon) => sourceIcon = icon);
    BitmapDescriptor.fromAssetImage(ImageConfiguration.empty, "")
        .then((icon) => destinationIcon = icon);
    BitmapDescriptor.fromAssetImage(ImageConfiguration.empty, "")
        .then((icon) => currentLocationIcon = icon);
  }

  void setProperties(BusStopDB busStopDB) async {
    print(
        "Loading all of the data from AppWrite  So Sit back and relax no rateLimit from google_____________");
    PolylinePoints polylinePoints = PolylinePoints();
    List<PointLatLng> result =
        polylinePoints.decodePolyline(busStopDB.polyLineString);

    if (result.isNotEmpty) {
      result.forEach((PointLatLng point) =>
          {polylineCoordinates.add(LatLng(point.latitude, point.longitude))});
    }
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
    int i = 0;
    busStopMarkers.clear();
    finalBusStopList = busStopDB.busStopList;
    busStopDB.busStopList.forEach((busStop) {
      print(busStop.lat);
      print(busStop.lng);
      busStopMarkers.add(
        Marker(
          markerId: MarkerId("${i++}"), // Unique marker ID
          position: LatLng(busStop.lat, busStop.lng),
          infoWindow: InfoWindow(
            title: 'Bus Stop',
            snippet: busStop.name,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueBlue,
          ),
        ),
      );
    });
    if (fromContinue) {
      currentTripId = (await db.getCurrentTrip())!;
      currentPassengerCount = await db.getCurrentPassengerCount(currentTripId);
    }
    if (!fromContinue) {
      busStopDB.currentLocationCoordinates = LatLng(
          currentLocation?.latitude ?? 0.0, currentLocation?.longitude! ?? 0.0);
      busStopDB.fromName = fromName;
      busStopDB.toName = toName;
      Document doc = await db.addTravelInfoDynamic(busStopDB);
      db.updateUserCurrentTrip(doc);
    }
    setState(() {
      completed = true;
    });
  }

  Future<void> startServer() async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
    print('Server running on port: ${_server?.port}');

    // Listen for incoming requests
    await for (var request in _server!) {
      // Handle the request
      print("Got the request");
      handleRequest(request);
    }
  }

  Future<void> stopServer() async {
    if (_server != null) {
      await _server?.close(force: true);
      _server = null;
      print('Server stopped.');
    }
  }

  void handleRequest(HttpRequest request) async {
    if (request.method == 'POST') {
      var content;
      var data;
      try {
        // Read the request body
        content = await utf8.decoder.bind(request).join();
        data = jsonDecode(content);
      } catch (e) {
        // Handle the case where "count" is not provided
        request.response
          ..statusCode = HttpStatus.badRequest
          ..write('Field "count" is missing.')
          ..close();
        return;
      }

      // Check if the "count" field is present in the POST data
      if (data.containsKey('count')) {
        final count = data['count'];
        print('Received count: $count');

        updatePassengerCount(count);

        // Respond to the client
        request.response
          ..statusCode = HttpStatus.ok
          ..write('Successfully received count: $count')
          ..close();
      } else {
        // Handle the case where "count" is not provided
        request.response
          ..statusCode = HttpStatus.badRequest
          ..write('Field "count" is missing.')
          ..close();
      }
    } else {
      // Handle non-POST requests
      request.response
        ..statusCode = HttpStatus.methodNotAllowed
        ..write('Only POST requests are allowed.')
        ..close();
    }
  }
}
