import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<bool> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  static Future<Position> getCurrentLocation() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      throw Exception('Location permission denied');
    }

    final settings = const LocationSettings(accuracy: LocationAccuracy.high);
    return await Geolocator.getCurrentPosition(locationSettings: settings);
  }
}
