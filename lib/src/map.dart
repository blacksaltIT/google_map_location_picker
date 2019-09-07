import 'dart:async';
import 'dart:convert';

import 'package:android_intent/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_map_location_picker/generated/i18n.dart';
import 'package:google_map_location_picker/src/providers/location_provider.dart';
import 'package:google_map_location_picker/src/utils/loading_builder.dart';
import 'package:google_map_location_picker/src/utils/log.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'model/location_result.dart';
import 'utils/location_utils.dart';

class MapPicker extends StatefulWidget {
  final LatLng initialCenter;
  final String apiKey;

  const MapPicker({
    Key key,
    this.initialCenter,
    this.apiKey,
  }) : super(key: key);

  @override
  MapPickerState createState() => MapPickerState();
}

class MapPickerState extends State<MapPicker> {
  Completer<GoogleMapController> mapController = Completer();

  MapType _currentMapType = MapType.normal;

  LatLng _lastMapPosition;

  Position _currentPosition;

  String _address;

  LocationResult _pinedLocationResult;

  void _onToggleMapTypePressed() {
    final MapType nextType =
        MapType.values[(_currentMapType.index + 1) % MapType.values.length];

    setState(() => _currentMapType = nextType);
  }

  void _onCurrentLocation() {
    _initCurrentLocation();
  }

  // this also checks for location permission.
  Future<void> _initCurrentLocation() async {
    Position currentPosition;
    try {
      currentPosition = await Geolocator()
          .getCurrentPosition(desiredAccuracy: LocationAccuracy.best);

      d("position = $currentPosition");

      setState(() => _currentPosition = currentPosition);
    } on PlatformException catch (e) {
      currentPosition = null;
      d("_initCurrentLocation#e = $e");
    }

    if (!mounted) return;

    setState(() => _currentPosition = currentPosition);

    if (currentPosition != null)
      moveToCurrentLocation(
          LatLng(currentPosition.latitude, currentPosition.longitude));
  }

  @override
  void initState() {
    super.initState();
    _initCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {
    _checkGps();
    _checkGeolocationPermission();
    return Scaffold(
      body: Builder(builder: (context) {
        if (_currentPosition == null)
          return const Center(child: CircularProgressIndicator());

        return buildMap();
      }),
    );
  }

  Widget buildMap() {
    return Center(
      child: Stack(
        children: <Widget>[
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              mapController.complete(controller);

              _lastMapPosition = widget.initialCenter;
              LocationProvider.of(context)
                  .adjustLastIdleLocation(_lastMapPosition);
            },
            initialCameraPosition: CameraPosition(
              target: widget.initialCenter,
              zoom: 11,
            ),
            onCameraMove: (CameraPosition position) {
              _lastMapPosition = position.target;
            },
            onCameraIdle: () async {
              print("onCameraIdle#_lastMapPosition = $_lastMapPosition");
              setState(() {
                LocationProvider.of(context)
                    .adjustLastIdleLocation(_lastMapPosition);
              });
            },
            onCameraMoveStarted: () {
              print("onCameraMoveStarted#_lastMapPosition = $_lastMapPosition");
            },
//            onTap: (latLng) {
//              clearOverlay();
//            },
            mapType: _currentMapType,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
          ),
          _MapFabs(
            onToggleMapTypePressed: _onToggleMapTypePressed,
            onCurrentLocation: _onCurrentLocation,
          ),
          pin(),
          locationCard(),
        ],
      ),
    );
  }

  Widget locationCard() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 30),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Consumer<LocationProvider>(
                builder: (context, locationProvider, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Flexible(
                    flex: 20,
                    child: FutureLoadingBuilder<String>(
                        future: getAddress(locationProvider.lastIdleLocation),
                        mutable: true,
                        loadingIndicator: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            CircularProgressIndicator(),
                          ],
                        ),
                        builder: (context, address) {
                          _address = address;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                address ?? 'Unnamed place',
                                style: TextStyle(
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          );
                        }),
                  ),
                  Spacer(),
                  FloatingActionButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        _pinedLocationResult ??
                            locationProvider.lastIdleLocation,
                      );
                    },
                    child: Icon(Icons.check, color: Colors.white, size: 28),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Future<String> getAddress(LocationResult location) async {
    if (location != null) {
      if (!location.isTypedIn) {
        try {
          var endPoint =
              'https://maps.googleapis.com/maps/api/geocode/json?latlng=${location?.latLng?.latitude},${location?.latLng?.longitude}&key=${widget.apiKey}';

          var response = await http.get(endPoint);

          if (response.statusCode == 200) {
            Map<String, dynamic> responseJson = jsonDecode(response.body);
            _pinedLocationResult = new LocationResult();
            LocationUtils.updateLocation(
                responseJson['results'][0], _pinedLocationResult);

            return _pinedLocationResult.address;
          }
        } catch (error) {
          print(error);
          return null;
        }
      } else {
        _pinedLocationResult = null;
        return location?.address;
      }
    } else
      return null;
  }

  Center pin() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.place, size: 56),
          Container(
            decoration: ShapeDecoration(
              shadows: [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 4,
                ),
              ],
              shape: CircleBorder(
                side: BorderSide(
                  width: 4,
                  color: Colors.transparent,
                ),
              ),
            ),
          ),
          SizedBox(height: 56),
        ],
      ),
    );
  }

  Future moveToCurrentLocation(LatLng currentLocation) async {
    var controller = await mapController.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: currentLocation, zoom: 19.151926040649414),
    ));
  }

  var dialogOpen;

  Future _checkGeolocationPermission() async {
    var geolocationStatus =
        await Geolocator().checkGeolocationPermissionStatus();

    if (geolocationStatus == GeolocationStatus.denied && dialogOpen == null) {
      d('showDialog');
      dialogOpen = showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: Text(S.of(context).access_to_location_denied ??
                'Access to location denied'),
            content: Text(
                S.of(context)?.allow_access_to_the_location_services ??
                    'Allow access to the location services.'),
            actions: <Widget>[
              FlatButton(
                child: Text(S.of(context)?.ok ?? 'Ok'),
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).pop();
                  _initCurrentLocation();
                  dialogOpen = null;
                },
              ),
            ],
          );
        },
      );
    } else if (geolocationStatus == GeolocationStatus.disabled) {
    } else if (geolocationStatus == GeolocationStatus.granted) {
      d('GeolocationStatus.granted');
      if (dialogOpen != null) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = null;
      }
    }
  }

  Future _checkGps() async {
    if (!(await Geolocator().isLocationServiceEnabled())) {
      if (Theme.of(context).platform == TargetPlatform.android) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(S.of(context)?.cant_get_current_location ??
                  "Can't get current location"),
              content: Text(S
                      .of(context)
                      ?.please_make_sure_you_enable_gps_and_try_again ??
                  'Please make sure you enable GPS and try again'),
              actions: <Widget>[
                FlatButton(
                  child: Text('Ok'),
                  onPressed: () {
                    final AndroidIntent intent = AndroidIntent(
                        action: 'android.settings.LOCATION_SOURCE_SETTINGS');

                    intent.launch();
                    Navigator.of(context, rootNavigator: true).pop();
                  },
                ),
              ],
            );
          },
        );
      }
    }
  }
}

class _MapFabs extends StatelessWidget {
  const _MapFabs({
    Key key,
    @required this.onToggleMapTypePressed,
    @required this.onCurrentLocation,
  })  : assert(onToggleMapTypePressed != null),
        assert(onCurrentLocation != null),
        super(key: key);

  final VoidCallback onToggleMapTypePressed;
  final VoidCallback onCurrentLocation;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.topRight,
      margin: const EdgeInsets.only(top: 16, right: 8),
      child: Column(
        children: <Widget>[
          FloatingActionButton(
            onPressed: onToggleMapTypePressed,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            mini: true,
            child: const Icon(Icons.layers, size: 28, color: Colors.white),
            heroTag: "layers",
          ),
          FloatingActionButton(
            onPressed: onCurrentLocation,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            mini: true,
            child: const Icon(Icons.my_location, size: 28, color: Colors.white),
            heroTag: "my_location",
          ),
        ],
      ),
    );
  }
}
