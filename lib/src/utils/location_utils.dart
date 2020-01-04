import 'dart:io';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:package_info/package_info.dart';
import 'package:flutter/services.dart';
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
        getAddressComponent('sublocality', result['address_components']);
    locationResult.country =
        getAddressComponent('country', result['address_components']);
    locationResult.postalCode =
        getAddressComponent('postal_code', result['address_components']);
    locationResult.latLng = latLng;
  }

  static const _platform = const MethodChannel('google_map_location_picker');
  static Map<String, String> _appHeaderCache = {};
  static Future<Map<String, String>> getAppHeaders() async {
    if (_appHeaderCache.isEmpty)
    {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();

      if (Platform.isIOS) {
          _appHeaderCache = {
            "X-Ios-Bundle-Identifier": packageInfo.packageName,
          };
      }
      else if (Platform.isAndroid) {
        String sha1;
        try {
          sha1 = await _platform.invokeMethod(
              'getSigningCertSha1', packageInfo.packageName);
        } on PlatformException {
          _appHeaderCache = {};
        }

        _appHeaderCache = {
          "X-Android-Package": packageInfo.packageName,
          "X-Android-Cert": sha1,
        };
      }
    }
      
    return _appHeaderCache;
  }
}
