import 'package:flutter/foundation.dart';

String addCorsPrefix(String url) {
  return (kIsWeb ? "https://cors-anywhere.herokuapp.com/" : "") + url;
}