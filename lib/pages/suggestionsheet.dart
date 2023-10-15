import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:travel_admin/services/database.dart';

class LocationSuggestion {
  final String description;
  final String placeId;

  LocationSuggestion({
    required this.description,
    required this.placeId,
  });
}

class LocationSuggestionSheet extends StatefulWidget {
  @override
  _LocationSuggestionSheetState createState() =>
      _LocationSuggestionSheetState();
}

class _LocationSuggestionSheetState extends State<LocationSuggestionSheet> {
  late DatabaseAPI db;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    db = DatabaseAPI();
  }

  TextEditingController _sourceController = TextEditingController();
  TextEditingController _destinationController = TextEditingController();
  late TextEditingController _focusedController;

  LatLng? source;
  LatLng? destination;

  final String apiKey = 'YOUR_API_KEY';

  // List to store location suggestions
  List<LocationSuggestion> _suggestions = [];

  // Method to fetch location suggestions from Google Places API
  Future<List<LocationSuggestion>> getSuggestions(String query) async {
    print("firing request to server");
    final String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=$apiKey&components=country:IN';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final predictions = json.decode(response.body)['predictions'] as List;
      return predictions
          .map<LocationSuggestion>((json) => LocationSuggestion(
                description: json['description'] as String,
                placeId: json['place_id'] as String,
              ))
          .toList();
    } else {
      throw Exception('Failed to load suggestions');
    }
  }

  // Method to update suggestions based on user input
  void updateSuggestions(TextEditingController controller, String query) async {
    final suggestions = await getSuggestions(query);
    setState(() {
      _suggestions = suggestions;
    });
  }

  // Method to fetch additional details using place ID
  Future<LatLng> getLatLngDetails(LocationSuggestion suggestion) async {
    final String detailsUrl =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=${suggestion.placeId}&key=$apiKey';

    final detailsResponse = await http.get(Uri.parse(detailsUrl));

    if (detailsResponse.statusCode == 200) {
      final details = json.decode(detailsResponse.body)['result'];
      final lat = details['geometry']['location']['lat'];
      final lng = details['geometry']['location']['lng'];

      print('Latitude: $lat, Longitude: $lng');

      return LatLng(lat, lng);
      // Perform actions with lat and lng
    } else {
      throw Exception('Failed to load details');
    }
  }

  void _setFocusedController(TextEditingController controller) {
    setState(() {
      _focusedController = controller;
    });
  }

  void onSuggestionTap(int index, TextEditingController controller) async {
    String selectedSuggestion = _suggestions[index].description;

    // Check which text field triggered the suggestion
    if (controller == _sourceController) {
      // This suggestion is for the source text field
      print('Source suggestion tapped: $selectedSuggestion');
      setState(() {
        _sourceController.text = selectedSuggestion;
      });
      source = await getLatLngDetails(_suggestions[index]);
    } else if (controller == _destinationController) {
      // This suggestion is for the destination text field
      print('Destination suggestion tapped: $selectedSuggestion');
      setState(() {
        _destinationController.text = selectedSuggestion;
      });
      destination = await getLatLngDetails(_suggestions[index]);
    }

    // Clear the suggestions after tapping
    setState(() {
      _suggestions = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add a Trip"),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top 30% of the screen
            Container(
              height: MediaQuery.of(context).size.height * 0.25,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // First text field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: TextField(
                      controller: _sourceController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.location_on),
                        hintText: 'Source Location',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(20.0),
                      ),
                      onChanged: (query) =>
                          updateSuggestions(_sourceController, query),
                      onTap: () => _setFocusedController(_sourceController),
                    ),
                  ),
                  // Second text field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: TextField(
                      controller: _destinationController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.location_on),
                        hintText: 'Destination Location',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(20.0),
                      ),
                      onChanged: (query) =>
                          updateSuggestions(_destinationController, query),
                      onTap: () =>
                          _setFocusedController(_destinationController),
                    ),
                  ),
                ],
              ),
            ),
            // Horizontal ruler
            Container(
              margin: const EdgeInsets.only(left: 20, right: 20),
              height: 5,
              color: Colors.grey[200],
            ),
            // Bottom 70% of the screen
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Suggestion list
                    Expanded(
                      child: ListView.builder(
                        itemCount: _suggestions.length,
                        itemBuilder: (context, index) {
                          final suggestion = _suggestions[index];
                          return Column(
                            children: [
                              ListTile(
                                contentPadding: const EdgeInsets.all(8.0),
                                leading: const Icon(Icons.location_on_outlined),
                                title: Text(
                                  suggestion.description,
                                  style: const TextStyle(
                                    fontSize: 18.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onTap: () {
                                  onSuggestionTap(index, _focusedController);
                                },
                              ),
                              // Remove the Divider if not needed
                              Divider(
                                height: 1.0,
                                thickness: 2.0,
                                color: Colors.grey[200],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (source != null && destination != null) {
            // Navigator.pushNamed(context, '/trip',
            //     arguments: {'source': source, 'dest': destination,'fromName' : _sourceController.text,'toName' : _destinationController.text});
            db.getBusStopDB(
                {'lat': source!.latitude, 'lng': source!.longitude}.toString(),
                {'lat': destination!.latitude, 'lng': destination!.longitude}
                    .toString());
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Please Enter Locations!")));
          }
        },
        child: Icon(Icons.arrow_forward_ios),
      ),
    );
  }
}
