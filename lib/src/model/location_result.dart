import 'package:google_maps_flutter/google_maps_flutter.dart';

/// The result returned after completing location selection.
class LocationResult {
  /// The human readable name of the location. This is primarily the
  /// name of the road. But in cases where the place was selected from Nearby
  /// places list, we use the <b>name</b> provided on the list item.
  String address; // or road
  String country;
  String locality;
  String subLocality;
  String route;
  String streetNumber;
  String postalCode;
  bool isTypedIn;

  /// Latitude/Longitude of the selected location.
  LatLng latLng;

  LocationResult(
      {this.latLng,
      this.address,
      this.country,
      this.isTypedIn = false,
      this.streetNumber,
      this.route,
      this.subLocality,
      this.locality,
      this.postalCode});

  @override
  String toString() {
    return 'LocationResult{address: $address, latLng: $latLng}';
  }
}
