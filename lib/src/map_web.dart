import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_map_location_picker/generated/i18n.dart';
import 'package:google_map_location_picker/src/providers/location_provider.dart';
import 'package:google_map_location_picker/src/utils/cors.dart';
import 'package:google_map_location_picker/src/utils/loading_builder.dart';
import 'package:google_map_location_picker/src/utils/log.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps/google_maps.dart' as googleDart;
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'model/location_result.dart';
import 'utils/location_utils.dart';
import 'package:location/location.dart';

class MapPicker extends StatefulWidget {
  final LatLng initialCenter;
  final String apiKey;
  final bool finalRefinement;
  final Stream<AppLifecycleState> lifecycleStream;

  const MapPicker(
      {Key key,
      this.initialCenter,
      this.apiKey,
      this.finalRefinement = false,
      this.lifecycleStream = null})
      : super(key: key);

  @override
  MapPickerState createState() => MapPickerState();
}

class MapPickerState extends State<MapPicker> {
  Completer<GoogleMapController> mapController = Completer();
  static LatLng _defaultPosition = const LatLng(45.521563, -122.677433);
  MapType _currentMapType = MapType.normal;
  LatLng _lastMapPosition;
  String _address;
  LocationResult _pinedLocationResult;
  bool locationEnabled = false;
  final formKey = new GlobalKey<FormState>();
  StreamSubscription _appLifecycleListener;
  Completer<googleDart.GMap> map = Completer();
  StreamSubscription onCenterChanged;
  StreamSubscription onIdle;
  int registryId;

  void _onToggleMapTypePressed() {
    final MapType nextType =
        MapType.values[(_currentMapType.index + 1) % MapType.values.length];

    setState(() => _currentMapType = nextType);
  }

  void _onCurrentLocation() async {
    if (!locationEnabled) {
      await AppSettings.openAppSettings();
    } else {
      await updateToCurrentPosition();

      setState(() {
        moveToCurrentLocation(_lastMapPosition);
      });
    }
  }

  void handleAppLifecycle() {
    if (widget.lifecycleStream != null) {
      _appLifecycleListener = widget.lifecycleStream.listen((state) async {
        if (state == AppLifecycleState.resumed) {
          locationEnabled = !kIsWeb
              ? (await Location().hasPermission() ==
                  PermissionStatus.granted)
              : false;

          if (locationEnabled)
            _onCurrentLocation();
          else
            setState(() {});
        }
      });
    }
  }

  // this also checks for location permission.
  Future<void> _initCurrentLocation() async {
    if (!mounted) return;

    locationEnabled = !kIsWeb
        ? (await Location().hasPermission() ==
            PermissionStatus.granted)
        : false;

    _lastMapPosition = widget.initialCenter ?? _defaultPosition;

    if (widget.initialCenter == null && locationEnabled)
      updateToCurrentPosition();

    setState(() {
      moveToCurrentLocation(_lastMapPosition);
    });
  }

  void updateToCurrentPosition() async {

    try {
       LocationData _locationData = await Location().getLocation();

  
      d("position = $_locationData");
      _lastMapPosition =
          LatLng(_locationData.latitude, _locationData.longitude);
    } on PlatformException catch (e) {
      d("_initCurrentLocation#e = $e");
    }
  }

  @override
  void initState() {
    super.initState();
    handleAppLifecycle();
    _initCurrentLocation();
    _initMapDiv();
  }

  @override
  void dispose() {
    if (_appLifecycleListener != null) _appLifecycleListener.cancel();
    if (onCenterChanged != null) onCenterChanged.cancel();
    if (onIdle != null) onIdle.cancel();

    super.dispose();
  }

  void _initMapDiv() {
    final mapOptions = new googleDart.MapOptions()
      ..zoom = 15
      ..center = new googleDart.LatLng(
          _lastMapPosition.latitude, _lastMapPosition.longitude)
      ..mapTypeControl = true;

    registryId = Random().nextInt(1000);

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory("map-content$registryId",
        (int viewId) {
      final elem = DivElement()
        ..id = "map-content"
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = 'none';
      googleDart.GMap googleMap = new googleDart.GMap(elem, mapOptions);

      onCenterChanged = googleMap.onCenterChanged.listen((onData) {
        _lastMapPosition = LatLng(googleMap.center.lat, googleMap.center.lng);
      });

      onIdle = googleMap.onIdle.listen((onData) {
        if (!map.isCompleted) map.complete(googleMap);
        if (mounted)
          setState(() {
            LocationProvider.of(context)
                .adjustLastIdleLocation(_lastMapPosition);
          });
      });

      return elem;
    });
  }

  @override
  Widget build(BuildContext context) {
    /*_checkGps();
    _checkGeolocationPermission();*/
    return Scaffold(
      body: Builder(builder: (context) {
        if (_lastMapPosition == null)
          return const Center(child: CircularProgressIndicator());

        return buildMap();
      }),
    );
  }

  googleDart.MapTypeId convertMapType(MapType type) {
    switch (type) {
      case MapType.none:
        return googleDart.MapTypeId.ROADMAP;
        break;
      case MapType.normal:
        return googleDart.MapTypeId.ROADMAP;
        break;
      case MapType.satellite:
        return googleDart.MapTypeId.SATELLITE;
        break;
      case MapType.terrain:
        return googleDart.MapTypeId.TERRAIN;
        break;
      case MapType.hybrid:
        return googleDart.MapTypeId.HYBRID;
        break;
    }
  }

  Widget buildMap() {
    return Center(
      child: Stack(
        children: <Widget>[
          kIsWeb
              ? HtmlElementView(viewType: "map-content$registryId")
              : GoogleMap(
                  onMapCreated: (GoogleMapController controller) {
                    mapController.complete(controller);
                    LocationProvider.of(context)
                        .adjustLastIdleLocation(_lastMapPosition);
                  },
                  initialCameraPosition: CameraPosition(
                    target: _lastMapPosition,
                    zoom: 11,
                  ),
                  onCameraMove: (CameraPosition position) {
                    _lastMapPosition = position.target;
                  },
                  onCameraIdle: () async {
                    setState(() {
                      LocationProvider.of(context)
                          .adjustLastIdleLocation(_lastMapPosition);
                    });
                  },
                  mapType: _currentMapType,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                ),
          if (!kIsWeb)
            _MapFabs(
              locationEnabled: locationEnabled,
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
                                address ?? "",
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
                    backgroundColor: Theme.of(context).dialogBackgroundColor,
                    onPressed: () {
                      LocationResult finalResult = _pinedLocationResult ??
                          locationProvider.lastIdleLocation;
                      if (widget.finalRefinement) {
                        TextEditingController routeController =
                            TextEditingController(text: finalResult.route);
                        TextEditingController numberController =
                            TextEditingController(
                                text: finalResult.streetNumber);
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            // return object of type Dialog
                            return SingleChildScrollView(
                                child: AlertDialog(
                              title: Text(S.of(context)?.picked_location ??
                                  'Picked location'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        "${finalResult.country}\n${finalResult.postalCode} ${finalResult.locality}\n${finalResult.subLocality ?? ""}",
                                        textAlign: TextAlign.left,
                                      )),
                                  TextFormField(
                                      controller: routeController,
                                      decoration: new InputDecoration(
                                          hintText: S.of(context)?.route ??
                                              'Public place',
                                          border: null),
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                      textAlign: TextAlign.center,
                                      maxLines: null),
                                  TextFormField(
                                      controller: numberController,
                                      decoration: new InputDecoration(
                                          hintText: S.of(context)?.number ??
                                              'Street, door number etc.',
                                          border: null),
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                      textAlign: TextAlign.center,
                                      maxLines: null),
                                  SizedBox(height: 10.0),
                                  Text(
                                      "${S.of(context)?.gps ?? 'GPS'}: ${finalResult.latLng.latitude.toStringAsFixed(5)}, ${finalResult.latLng.longitude.toStringAsFixed(5)}")
                                ],
                              ),
                              actions: <Widget>[
                                new FlatButton(
                                  child: Text(S.of(context)?.close ?? 'Close'),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                ),
                                new FlatButton(
                                  child:
                                      Text(S.of(context)?.submit ?? 'Submit'),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    finalResult.route =
                                        routeController.value.text;
                                    finalResult.streetNumber =
                                        numberController.value.text;
                                    finalResult.address =
                                        "${finalResult.locality}, ${finalResult.route} ${finalResult.streetNumber}, ${finalResult.postalCode} ${finalResult.country}";
                                    Navigator.of(context).pop(finalResult);
                                  },
                                )
                              ],
                            ));
                          },
                        );
                      }
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
          var endPoint = addCorsPrefix('https://maps.googleapis.com/maps/api/geocode/json?latlng=${location?.latLng?.latitude},${location?.latLng?.longitude}&key=${widget.apiKey}');

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
    var controller = await map.future;
    controller.panTo(
        googleDart.LatLng(currentLocation.latitude, currentLocation.longitude));
  }

  var dialogOpen;

  Future _checkGeolocationPermission() async {
    var geolocationStatus =
        await Location().hasPermission();

    if ((geolocationStatus == PermissionStatus.denied || geolocationStatus == PermissionStatus.deniedForever) && dialogOpen == null) {
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
    } else if (geolocationStatus == PermissionStatus.granted) {
      d('GeolocationStatus.granted');
      if (dialogOpen != null) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = null;
      }
    }
  }

  Future _checkGps() async {
    if (!(await Location().serviceEnabled())) {
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
                    AppSettings.openAppSettings();
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
  const _MapFabs(
      {Key key,
      @required this.onToggleMapTypePressed,
      @required this.onCurrentLocation,
      @required this.locationEnabled})
      : assert(locationEnabled != null),
        assert(onToggleMapTypePressed != null),
        assert(onCurrentLocation != null),
        super(key: key);

  final ui.VoidCallback onToggleMapTypePressed;
  final ui.VoidCallback onCurrentLocation;
  final bool locationEnabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      margin: const EdgeInsets.only(top: 16, right: 8),
      child: Column(
        children: <Widget>[
          FloatingActionButton(
            backgroundColor: Theme.of(context).dialogBackgroundColor,
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
              child: Icon(
                  locationEnabled == true
                      ? Icons.my_location
                      : Icons.location_disabled,
                  size: 28,
                  color: Colors.white),
              heroTag: "my_location",
              backgroundColor: locationEnabled ? Theme.of(context).dialogBackgroundColor : Colors.red),
        ],
      ),
    );
  }
}
