import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../model/location_result.dart';

class LocationProvider extends ChangeNotifier {
  static LocationProvider of(BuildContext context) =>
      Provider.of<LocationProvider>(context, listen: false);

  LocationResult _lastIdleLocation;

  LocationResult get lastIdleLocation => _lastIdleLocation;

  void setLastIdleLocation(LocationResult lastIdleLocation) {
    if (_lastIdleLocation != lastIdleLocation) {
      _lastIdleLocation = lastIdleLocation;
      notifyListeners();
    }
  }

  void adjustLastIdleLocation(LatLng latLng) {
    if (_lastIdleLocation == null) _lastIdleLocation = LocationResult();
    _lastIdleLocation.latLng = latLng;
  }
}
