import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../model/location_result.dart';

class LocationUtils {
  static String getAddressComponent(String type, List addressComponents) {
    for (Map<String, dynamic> component in addressComponents) {
      if ((component['types'] as List).contains(type))
        return component['long_name'];
    }
    return null;
  }

  static void updateLocation(
      Map<String, dynamic> result, LocationResult locationResult) {
    Map<String, dynamic> location = result['geometry']['location'];

    LatLng latLng = LatLng(location['lat'], location['lng']);

    locationResult.address = result['formatted_address'];
    locationResult.streetNumber =
        getAddressComponent('street_number', result['address_components']);
    locationResult.route =
        getAddressComponent('route', result['address_components']);
    locationResult.locality =
        getAddressComponent('locality', result['address_components']);
    locationResult.subLocality =
        getAddressComponent('sub_locality', result['address_components']);
    locationResult.country =
        getAddressComponent('country', result['address_components']);
    locationResult.postalCode =
        getAddressComponent('postalCode', result['address_components']);
    locationResult.latLng = latLng;
  }
}
