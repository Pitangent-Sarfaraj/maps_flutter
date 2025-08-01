import 'package:location/location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationService {
  static final Location _location = Location();

  static PermissionStatus? _cachedPermission;
  static bool? _cachedServiceStatus;

  Future<LatLng?> getCurrentLocation() async {
    try {
      if (_cachedServiceStatus == null) {
        _cachedServiceStatus = await _location.serviceEnabled();
        Future.delayed(Duration(seconds: 30), () => _cachedServiceStatus = null);
      }

      if (!_cachedServiceStatus!) {
        _cachedServiceStatus = await _location.requestService();
        if (!_cachedServiceStatus!) return null;
      }

      if (_cachedPermission == null) {
        _cachedPermission = await _location.hasPermission();
      }

      if (_cachedPermission == PermissionStatus.denied) {
        _cachedPermission = await _location.requestPermission();
        if (_cachedPermission != PermissionStatus.granted) return null;
      }

      LocationData locationData = await _location.getLocation().timeout(
        Duration(seconds: 10),
        onTimeout: () => throw Exception('Location request timed out'),
      );

      if (locationData.latitude == null || locationData.longitude == null) {
        throw Exception('Invalid location data received');
      }

      return LatLng(locationData.latitude!, locationData.longitude!);
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  Stream<LatLng> getLocationStream() {
    return _location.onLocationChanged
        .where((locationData) =>
    locationData.latitude != null && locationData.longitude != null)
        .map((locationData) => LatLng(locationData.latitude!, locationData.longitude!))
        .distinct()
        .handleError((error) {
      print('Location stream error: $error');
    });
  }

  static void clearCache() {
    _cachedPermission = null;
    _cachedServiceStatus = null;
  }
}