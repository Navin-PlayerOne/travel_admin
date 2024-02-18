import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:travel_admin/models/model.dart';
import 'package:travel_admin/pages/suggestionsheet.dart';
import 'package:travel_admin/services/database.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late DatabaseAPI db;
  int isContinue = -1;
  late TripTemplate tempalte;
  String? currentTripId;

  @override
  void initState() {
    db = DatabaseAPI();
    print("init state");
    loadTrip();
  }

  void loadTrip() async {
    currentTripId = await db.getCurrentTrip();
    if (currentTripId != null) {
      try {
        tempalte = (await db.fetchTripInfo(currentTripId!))!;
      } catch (e) {
        setState(() {
          isContinue = 0;
        });
      }
    }
    if (currentTripId != null) {
      setState(() {
        isContinue = 1;
      });
    } else {
      setState(() {
        isContinue = 0;
      });
    }
  }

  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SingleChildScrollView(
          child: SizedBox(
            height: 800,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(25.0),
                  topRight: Radius.circular(25.0),
                ),
              ),
              child: LocationSuggestionSheet(),
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
        title: Text(
          'Travel Admin',
          style: GoogleFonts.poppins(fontSize: 25),
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: bodyWidget(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showBottomSheet(context);
        },
        child: const Icon(Icons.add_location_alt_outlined),
      ),
    );
  }

  bodyWidget() {
    switch (isContinue) {
      case -1:
        return const Center(
          child: SpinKitSquareCircle(
            size: 200,
            color: Colors.indigo,
          ),
        );
      case 0:
        return const Center(child: Text('No Trip found!'));
      case 1:
        return Center(
          child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Theme.of(context).colorScheme.secondaryContainer,
              ),
              height: 350,
              width: 400,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Let's get back on the road!",
                              style: GoogleFonts.poppins(fontSize: 24),
                              maxLines: 1,
                              overflow: TextOverflow.fade),
                          ...getColumn("From", tempalte.fromName),
                          ...getColumn("To", tempalte.toName),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton(
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/trip',
                                        arguments: {
                                          'source': tempalte.from,
                                          'dest': tempalte.to,
                                          'fromName': tempalte.fromName,
                                          'toName': tempalte.toName,
                                          'fromContinue': true
                                        });
                                  },
                                  child: const Text('continue')),
                              ElevatedButton(
                                  onPressed: () {},
                                  child: const Text('Mark as complete')),
                              ElevatedButton(
                                  style: ButtonStyle(
                                    backgroundColor:
                                        MaterialStateProperty.all<Color>(
                                            Colors.redAccent),
                                  ),
                                  onPressed: () {},
                                  child: const Text('X')),
                            ],
                          ),
                        ]),
                  ),
                ],
              )),
        );
    }
  }
}

List<Widget> getColumn(String arg1, String arg2, {bool showToolTip = false}) {
  return [
    Padding(
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
      child: Row(
        children: [
          Text(arg1,
              style: GoogleFonts.poppins(fontSize: 23),
              maxLines: 1,
              overflow: TextOverflow.fade),
          showToolTip
              ? const Tooltip(
                  message: 'This indicates the size of each parts',
                  triggerMode: TooltipTriggerMode
                      .tap, // ensures the label appears when tapped
                  preferBelow:
                      false, // use this if you want the label above the widget
                  child: Icon(Icons.info),
                )
              : Container()
        ],
      ),
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 10),
      child: Text(arg2,
          style: GoogleFonts.poppins(fontSize: 17),
          maxLines: 1,
          overflow: TextOverflow.fade),
    )
  ];
}
