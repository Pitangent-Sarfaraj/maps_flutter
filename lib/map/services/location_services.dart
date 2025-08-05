import 'dart:developer';
import 'dart:math' as math;
import 'package:location/location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationServicess {
  static final Location _location = Location();

  static PermissionStatus? _cachedPermission;
  static bool? _cachedServiceStatus;

  Stream<LatLng> getNavigationLocationStream() {
    return _location.onLocationChanged
        .where((locationData) =>
    locationData.latitude != null &&
        locationData.longitude != null &&
        locationData.accuracy != null &&
        locationData.accuracy! < 50)
        .map((locationData) =>
        LatLng(locationData.latitude!, locationData.longitude!))
        .distinct((previous, next) {
      // Only emit if moved more than 5 meters
      const double threshold = 5.0; // meters
      double distance = _calculateDistance(previous, next);
      return distance > threshold;
    })
        .handleError((error) {
      print('Navigation location stream error: $error');
    });
  }

  double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371000; // Earth's radius in meters

    double lat1Rad = start.latitude * (math.pi / 180);
    double lat2Rad = end.latitude * (math.pi / 180);
    double deltaLatRad = (end.latitude - start.latitude) * (math.pi / 180);
    double deltaLngRad = (end.longitude - start.longitude) * (math.pi / 180);

    double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLngRad / 2) *
            math.sin(deltaLngRad / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  Future<void> enableNavigationMode() async {
    await _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 1000,
      distanceFilter: 0,
    );
  }

  Future<void> disableNavigationMode() async {
    await _location.changeSettings(
      accuracy: LocationAccuracy.balanced,
      interval: 5000,
      distanceFilter: 10,
    );
  }

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
      log('CurrentLatLon=====>${locationData.latitude!} ${locationData.longitude!}');
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
