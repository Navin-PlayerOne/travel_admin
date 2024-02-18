import 'dart:async';

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
  @override
  void initState() {
    super.initState();
    isFirst = true;
    db = DatabaseAPI();
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
  bool fromContinue = false;
  int currentPassengerCount = 0;

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

    // location.onLocationChanged.listen((newLocation) {
    //   currentLocation = newLocation;

    //   googleMapController.animateCamera(CameraUpdate.newCameraPosition(
    //       CameraPosition(
    //           zoom: 13.5,
    //           target: LatLng(newLocation.latitude!, newLocation.longitude!))));
    //   setState(() {});
    // });
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

    //remove duplicates
    finalBusStopList = removeDuplicates(finalBusStopList);

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
      DatabaseAPI api = DatabaseAPI();
      api.updatePassengerCount(await api.getCurrentTrip() ?? '', count);
    }
  }

  void tryCaching() async {
    final result = await db.getBusStopDB(
        {'lat': sourceLocation.latitude, 'lng': sourceLocation.longitude}
            .toString(),
        {'lat': destination!.latitude, 'lng': destination!.longitude}
            .toString());
    if (result != null) {
      getCurrentLocation();
      setProperties(result);
      //db.updateUserCurrentTrip(currentTripId);
    } else {
      print("New data so loading it from google !!!!!!!!!!!!!!");
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
      getCurrentLocation();
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
    if (!fromContinue) {
      busStopDB.currentLocationCoordinates = LatLng(0.0, 0.0);
      busStopDB.fromName = fromName;
      busStopDB.toName = toName;
      Document doc = await db.addTravelInfoDynamic(busStopDB);
      db.updateUserCurrentTrip(doc);
    }
    setState(() {
      completed = true;
    });
  }
}
