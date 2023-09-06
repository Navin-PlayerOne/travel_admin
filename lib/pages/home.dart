import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:geocoding/geocoding.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _startLocationController =
      TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  List<String> startLocationSuggestions = [];
  List<String> destinationSuggestions = [];

  List<Location> startLocations = [];
  List<Location> destLocations = [];

  @override
  void initState() {
    super.initState();
  }

  Future<List<String>> _getSuggestions(String query) async {
    try {
      final location = await locationFromAddress(query);
      startLocations = location;
      final locations = await Future.wait(location.map((coordinates) =>
          placemarkFromCoordinates(
              coordinates.latitude, coordinates.longitude)));

      return locations
          .map((location) =>
              "${location.first.locality}, ${location.first.administrativeArea}, ${location.first.country}")
          .toList();
    } catch (e) {
      print('Error fetching location suggestions: $e');
      return [];
    }
  }

  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SingleChildScrollView(
          child: SizedBox(
            height: 600,
            child: Container(
              padding: EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text('Create a Trip'),
                  SizedBox(height: 16.0),
                  TypeAheadFormField<String>(
                    textFieldConfiguration: TextFieldConfiguration(
                      controller: _startLocationController,
                      decoration: InputDecoration(
                        labelText: 'Choose start location',
                      ),
                    ),
                    suggestionsCallback: (pattern) async {
                      final suggestions = await _getSuggestions(pattern);
                      setState(() {
                        startLocationSuggestions =
                            suggestions; // Update suggestion list
                      });
                      return suggestions;
                    },
                    itemBuilder: (context, suggestion) {
                      return ListTile(
                        title: Text(
                          suggestion,
                          style: TextStyle(fontSize: 18.0),
                        ),
                      );
                    },
                    onSuggestionSelected: (suggestion) {
                      final index =
                          startLocationSuggestions.indexOf(suggestion);

                      print('Selected suggestion index: $index');
                      print('Selected suggestion: $suggestion');

                      _startLocationController.text = suggestion;
                    },
                  ),
                  SizedBox(height: 16.0),
                  TypeAheadFormField<String>(
                    textFieldConfiguration: TextFieldConfiguration(
                      controller: _destinationController,
                      decoration: InputDecoration(
                        labelText: 'Choose destination',
                      ),
                    ),
                    suggestionsCallback: (pattern) async {
                      final suggestions = await _getSuggestions(pattern);
                      setState(() {
                        destinationSuggestions =
                            suggestions; // Update suggestion list
                      });
                      return suggestions;
                    },
                    itemBuilder: (context, suggestion) {
                      return ListTile(
                        title: Text(
                          suggestion,
                          style: TextStyle(fontSize: 18.0),
                        ),
                      );
                    },
                    onSuggestionSelected: (suggestion) {
                      final index = destinationSuggestions.indexOf(suggestion);

                      print('Selected suggestion index: $index');
                      print('Selected suggestion: $suggestion');

                      _destinationController.text = suggestion;
                    },
                  ),
                  SizedBox(height: 16.0),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text('Start travel'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Travel Admin'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {},
          child: Text('Show Bottom Sheet'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showBottomSheet(context);
        },
        child: Icon(Icons.add_location_alt_outlined),
      ),
    );
  }
}
