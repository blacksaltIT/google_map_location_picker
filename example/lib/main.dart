import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_map_location_picker/generated/i18n.dart'
    as location_picker;
import 'package:google_map_location_picker/google_map_location_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;

import 'generated/i18n.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  LocationResult _pickedLocation;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'location picker',
      localizationsDelegates: const [
        location_picker.S.delegate,
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
          // This is the theme of your application.
          //
          // Try running your application with "flutter run". You'll see the
          // application has a blue toolbar. Then, without quitting the app, try
          // changing the primarySwatch below to Colors.green and then invoke
          // "hot reload" (press "r" in the console where you ran "flutter run",
          // or simply save your changes to "hot reload" in a Flutter IDE).
          // Notice that the counter didn't reset back to zero; the application
          // is not restarted.
          brightness: Brightness.dark,
          fontFamily: 'Roboto',
          primaryColor: Colors.red[300],
          accentColor: Colors.cyan[800],
          iconTheme: IconThemeData(color: Colors.cyan[800], size: 30)
    
          ),
      supportedLocales: const <Locale>[
        Locale('en', ''),
        Locale('ar', ''),
      ],
      home: Scaffold(
       
        body: Builder(builder: (context) {
          return Center(
            child: FlatButton(child: Text("Location"),onPressed: (){
              Navigator.push(context, MaterialPageRoute(builder: (context) {
                return LocationPage();
              }));
            },)
          );
        }),
      ),
    );
  }
}

class LocationPage extends StatefulWidget {
  @override
  _LocationPageState createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
       
        body: Builder(builder: (context) {
          return Center(
            child: AddressPicker(
                  "YOUR_API_KEY",
                  finalRefinement: true,
                  initialCenter
                          : gm.LatLng(47.497913, 19.040236))
          );
        }),
    );
  }
}
