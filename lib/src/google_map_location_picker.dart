import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_map_location_picker/generated/i18n.dart';
import 'package:google_map_location_picker/src/map.dart' 
  if (dart.library.html) 'package:google_map_location_picker/src/map_web.dart'
  if (dart.library.io) 'package:google_map_location_picker/src/map.dart';
import 'package:google_map_location_picker/src/providers/location_provider.dart';
import 'package:google_map_location_picker/src/rich_suggestion.dart';
import 'package:google_map_location_picker/src/search_input.dart';
import 'package:google_map_location_picker/src/utils/uuid.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'model/auto_comp_iete_item.dart';
import 'model/location_result.dart';
import 'model/nearby_place.dart';
import 'utils/location_utils.dart';

class AddressPicker extends StatefulWidget {
  AddressPicker(this.apiKey,
      {Key key,
      this.initialCenter,
      this.finalRefinement = false,
      this.lifecycleStream = null});

  final String apiKey;
  final LatLng initialCenter;
  final bool finalRefinement;
  final Stream<AppLifecycleState> lifecycleStream;

  @override
  AddressPickerState createState() => AddressPickerState();
}

class AddressPickerState extends State<AddressPicker> {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
        providers: [
          ChangeNotifierProvider(builder: (_) => LocationProvider()),
        ],
        child: Builder(builder: (context) {
          return LocationPicker(widget.apiKey,
              initialCenter: widget.initialCenter,
              finalRefinement: widget.finalRefinement,
              lifecycleStream: widget.lifecycleStream);
        }));
  }
}

class LocationPicker extends StatefulWidget {
  LocationPicker(this.apiKey,
      {Key key,
      this.initialCenter,
      this.finalRefinement,
      this.lifecycleStream});

  final String apiKey;
  final LatLng initialCenter;
  final bool finalRefinement;
  final Stream<AppLifecycleState> lifecycleStream;

  @override
  LocationPickerState createState() => LocationPickerState();

  /// Returns a [LatLng] object of the location that was picked.
  ///
  /// The [apiKey] argument API key generated from Google Cloud Console.
  /// You can get an API key [here](https://cloud.google.com/maps-platform/)
  ///
  /// [initialCenter] The geographical location that the camera is pointing at.
  ///
  static Future<LocationResult> pickLocation(
    BuildContext context,
    String apiKey, {
    LatLng initialCenter = const LatLng(45.521563, -122.677433),
  }) async {
    var results = await Navigator.of(context).push(
      MaterialPageRoute<dynamic>(
        builder: (BuildContext context) {
          return LocationPicker(
            apiKey,
            initialCenter: initialCenter,
          );
        },
      ),
    );

    if (results != null && results.containsKey('location')) {
      return results['location'];
    } else {
      return null;
    }
  }
}

class LocationPickerState extends State<LocationPicker> {
  /// Result returned after user completes selection
  LocationResult locationResult;

  /// Overlay to display autocomplete suggestions
  OverlayEntry overlayEntry;

  List<NearbyPlace> nearbyPlaces = List();

  /// Session token required for autocomplete API call
  String sessionToken = Uuid().generateV4();

  var mapKey = GlobalKey<MapPickerState>();

  var appBarKey = GlobalKey();

  var searchInputKey = GlobalKey<SearchInputState>();

  bool hasSearchTerm = false;

  /// Hides the autocomplete overlay
  void clearOverlay() {
    if (overlayEntry != null) {
      overlayEntry.remove();
      overlayEntry = null;
    }
  }

  /// Begins the search process by displaying a "wait" overlay then
  /// proceeds to fetch the autocomplete list. The bottom "dialog"
  /// is hidden so as to give more room and better experience for the
  /// autocomplete list overlay.
  void searchPlace(String place) {
    if (context == null) return;

    clearOverlay();

    setState(() => hasSearchTerm = place.length > 0);

    if (place.length < 1) return;

    final RenderBox renderBox = context.findRenderObject();
    Size size = renderBox.size;

    final RenderBox appBarBox = appBarKey.currentContext.findRenderObject();

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: appBarBox.size.height,
        width: size.width,
        child: Material(
          elevation: 1,
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 24,
            ),
            color: Colors.white,
            child: Row(
              children: <Widget>[
                SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                  ),
                ),
                SizedBox(
                  width: 24,
                ),
                Expanded(
                  child: Text(
                    S.of(context)?.finding_place ?? "Finding place...",
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);

    autoCompleteSearch(place);
  }

  /// Fetches the place autocomplete list with the query [place].
  void autoCompleteSearch(String place) {
    place = place.replaceAll(" ", "+");
    var endpoint =
        "https://cors-anywhere.herokuapp.com/https://maps.googleapis.com/maps/api/place/autocomplete/json?" +
            "key=${widget.apiKey}&" +
            "input={$place}&sessiontoken=$sessionToken";

    if (locationResult != null) {
      endpoint += "&location=${locationResult.latLng.latitude}," +
          "${locationResult.latLng.longitude}";
    }
    http.get(endpoint).then((response) {
      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);
        List<dynamic> predictions = data['predictions'];

        List<RichSuggestion> suggestions = [];

        if (predictions.isEmpty) {
          AutoCompleteItem aci = AutoCompleteItem();
          aci.text = "No result found";
          aci.offset = 0;
          aci.length = 0;

          suggestions.add(RichSuggestion(aci, () {}));
        } else {
          for (dynamic t in predictions) {
            AutoCompleteItem aci = AutoCompleteItem();

            aci.id = t['place_id'];
            aci.text = t['description'];
            aci.offset = t['matched_substrings'][0]['offset'];
            aci.length = t['matched_substrings'][0]['length'];

            suggestions.add(RichSuggestion(aci, () {
              decodeAndSelectPlace(aci.id);
            }));
          }
        }

        displayAutoCompleteSuggestions(suggestions);
      }
    }).catchError((error) {
      print(error);
    });
  }

  /// To navigate to the selected place from the autocomplete list to the map,
  /// the lat,lng is required. This method fetches the lat,lng of the place and
  /// proceeds to moving the map to that location.
  void decodeAndSelectPlace(String placeId) {
    clearOverlay();

    String endpoint =
        "https://cors-anywhere.herokuapp.com/https://maps.googleapis.com/maps/api/place/details/json?key=${widget.apiKey}" +
            "&placeid=$placeId";

    http.get(endpoint).then((response) {
      if (response.statusCode == 200) {
        Map<String, dynamic> responseJson = jsonDecode(response.body);
        setState(() {
          locationResult = new LocationResult();
          LocationUtils.updateLocation(responseJson['result'], locationResult);
          locationResult.isTypedIn = true;
          LocationProvider.of(context).setLastIdleLocation(locationResult);
        });

        moveToLocation(locationResult.latLng);
      }
    }).catchError((error) {
      print(error);
    });
  }

  /// Display autocomplete suggestions with the overlay.
  void displayAutoCompleteSuggestions(List<RichSuggestion> suggestions) {
    final RenderBox renderBox = context.findRenderObject();
    Size size = renderBox.size;

    final RenderBox appBarBox = appBarKey.currentContext.findRenderObject();

    clearOverlay();

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        top: appBarBox.size.height,
        child: Material(
          elevation: 1,
          color: Colors.white,
          child: Column(
            children: suggestions,
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);
  }

  /// Utility function to get clean readable name of a location. First checks
  /// for a human-readable name from the nearby list. This helps in the cases
  /// that the user selects from the nearby list (and expects to see that as a
  /// result, instead of road name). If no name is found from the nearby list,
  /// then the road name returned is used instead.
//  String getLocationName() {
//    if (locationResult == null) {
//      return "Unnamed location";
//    }
//
//    for (NearbyPlace np in nearbyPlaces) {
//      if (np.latLng == locationResult.latLng) {
//        locationResult.name = np.name;
//        return np.name;
//      }
//    }
//
//    return "${locationResult.name}, ${locationResult.locality}";
//  }

  /// Fetches and updates the nearby places to the provided lat,lng
  void getNearbyPlaces(LatLng latLng) {
    http
        .get("https://cors-anywhere.herokuapp.com/https://maps.googleapis.com/maps/api/place/nearbysearch/json?" +
            "key=${widget.apiKey}&" +
            "location=${latLng.latitude},${latLng.longitude}&radius=150")
        .then((response) {
      if (response.statusCode == 200) {
        nearbyPlaces.clear();
        for (Map<String, dynamic> item
            in jsonDecode(response.body)['results']) {
          NearbyPlace nearbyPlace = NearbyPlace();

          nearbyPlace.name = item['name'];
          nearbyPlace.icon = item['icon'];
          double latitude = item['geometry']['location']['lat'];
          double longitude = item['geometry']['location']['lng'];

          LatLng _latLng = LatLng(latitude, longitude);

          nearbyPlace.latLng = _latLng;

          nearbyPlaces.add(nearbyPlace);
        }
      }

      // to update the nearby places
      setState(() {
        // this is to require the result to show
        hasSearchTerm = false;
      });
    }).catchError((error) {});
  }

  /// This method gets the human readable name of the location. Mostly appears
  /// to be the road name and the locality.
  Future reverseGeocodeLatLng(LatLng latLng) async {
    var response = await http.get(
        "https://cors-anywhere.herokuapp.com/https://maps.googleapis.com/maps/api/geocode/json?latlng=${latLng.latitude},${latLng.longitude}"
        "&key=${widget.apiKey}");

    if (response.statusCode == 200) {
      Map<String, dynamic> responseJson = jsonDecode(response.body);
      setState(() {
        locationResult = new LocationResult();
        LocationUtils.updateLocation(
            responseJson['results'][0], locationResult);
        LocationProvider.of(context).setLastIdleLocation(locationResult);
      });
    }
  }

  Future reverseGeocodeAddress(String address) async {
    var response = await http.get(
        "https://cors-anywhere.herokuapp.com/https://maps.googleapis.com/maps/api/geocode/json?address=${address}"
        "&key=${widget.apiKey}");

    if (response.statusCode == 200) {
      Map<String, dynamic> responseJson = jsonDecode(response.body);
      setState(() {
        locationResult = new LocationResult();
        LocationUtils.updateLocation(
            responseJson['results'][0], locationResult);
        LocationProvider.of(context).setLastIdleLocation(locationResult);
      });
    }
  }

  /// Moves the camera to the provided location and updates other UI features to
  /// match the location.
  void moveToLocation(LatLng latLng) {
    mapKey.currentState.moveToCurrentLocation(latLng);
    //reverseGeocodeLatLng(latLng);
    //getNearbyPlaces(latLng);
  }

  @override
  void dispose() {
    clearOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          iconTheme: Theme.of(context).iconTheme,
          key: appBarKey,
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: SearchInput(
              (input) => searchPlace(input),
              key: searchInputKey,
            ),
          ),
        ),
        body: MapPicker(
          initialCenter: widget.initialCenter,
          key: mapKey,
          apiKey: widget.apiKey,
          finalRefinement: widget.finalRefinement,
          lifecycleStream: widget.lifecycleStream,
        ));
  }
}
