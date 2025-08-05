  import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../providers/providers.dart';

class NavigationController {
  final Ref ref;
  StreamSubscription<LatLng?>? _navigationSubscription;
  DateTime? _navigationStartTime;
  LatLng? _startLocation;
  double _totalDistanceTraveled = 0.0;
  LatLng? _lastKnownLocation;

  NavigationController(this.ref);

  void startNavigation() {
    final destination = ref.read(selectedDestinationProvider);
    final currentLocation = ref.read(currentLocationProvider).value;

    if (destination == null || currentLocation == null) {
      print('Cannot start navigation: missing destination or current location');
      return;
    }

    _navigationStartTime = DateTime.now();
    _startLocation = currentLocation;
    _totalDistanceTraveled = 0.0;
    _lastKnownLocation = currentLocation;

    ref.read(isInNavigationModeProvider.notifier).state = true;
    ref.read(navigationStartTimeProvider.notifier).state = _navigationStartTime;

    final locationService = ref.read(locationServiceProvider);
    locationService.enableNavigationMode();

    _navigationSubscription =
        ref.read(realTimeLocationProvider.stream).listen((location) {
      if (location != null) {
        _updateNavigationProgress(location, destination);
      }
    });

    print(
        'Navigation started to ${destination.latitude}, ${destination.longitude}');
  }

  void _updateNavigationProgress(LatLng currentLocation, LatLng destination) {
    if (_navigationStartTime == null || _lastKnownLocation == null) return;

    final distanceToDestination =
        _calculateDistance(currentLocation, destination);

    final distanceSinceLastUpdate =
        _calculateDistance(_lastKnownLocation!, currentLocation);
    _totalDistanceTraveled += distanceSinceLastUpdate;

    final timeElapsed = DateTime.now().difference(_navigationStartTime!);

    final averageSpeed = timeElapsed.inSeconds > 0
        ? (_totalDistanceTraveled / 1000) / (timeElapsed.inSeconds / 3600)
        : 0.0;

    final estimatedTimeRemaining = averageSpeed >
            0.5 // Only if moving reasonably fast
        ? Duration(
            seconds:
                ((distanceToDestination / 1000) / averageSpeed * 3600).round())
        : Duration.zero;

    final progress = NavigationProgress(
      distanceRemaining: distanceToDestination,
      distanceTraveled: _totalDistanceTraveled,
      timeElapsed: timeElapsed,
      estimatedTimeRemaining: estimatedTimeRemaining,
      averageSpeed: averageSpeed,
    );

    ref.read(navigationProgressProvider.notifier).state = progress;
    ref.read(liveDistanceProvider.notifier).state = distanceToDestination;

    ref.read(markersProvider.notifier).addMarker(
          currentLocation,
          "current_location",
          title: "You are here",
        );

    if (distanceToDestination < 50) {
      _onDestinationReached();
    }

    _lastKnownLocation = currentLocation;
  }

  void stopNavigation() {
    _navigationSubscription?.cancel();
    _navigationSubscription = null;

    final locationService = ref.read(locationServiceProvider);
    locationService.disableNavigationMode();

    ref.read(isInNavigationModeProvider.notifier).state = false;
    ref.read(navigationStartTimeProvider.notifier).state = null;
    ref.read(navigationProgressProvider.notifier).state = null;
    ref.read(estimatedArrivalTimeProvider.notifier).state = null;

    _navigationStartTime = null;
    _startLocation = null;
    _totalDistanceTraveled = 0.0;
    _lastKnownLocation = null;

    print('Navigation stopped');
  }

  void _onDestinationReached() {
    print('Destination reached!');
    stopNavigation();
  }

  double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371000;

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

  void dispose() {
    _navigationSubscription?.cancel();
  }
}

final navigationControllerProvider = Provider<NavigationController>((ref) {
  return NavigationController(ref);
});
