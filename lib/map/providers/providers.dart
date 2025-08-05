import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:maps_flutter/map/models/travel_mode.dart';
import '../services/location_services.dart';
import '../services/route_services.dart';

final locationServiceProvider = Provider<LocationServicess>((ref) {
  return LocationServicess();
});

final geofenceCircleProvider = StateProvider<Set<Circle>>((ref) => {});
final isInNavigationModeProvider = StateProvider<bool>((ref) => false);
final navigationStartTimeProvider = StateProvider<DateTime?>((ref) => null);
final estimatedArrivalTimeProvider = StateProvider<DateTime?>((ref) => null);
final realTimeLocationProvider = StreamProvider<LatLng?>((ref) {
  final locationService = ref.watch(locationServiceProvider);
  return locationService.getLocationStream();
});
final navigationMarkerProvider = StateProvider<Marker?>((ref) => null);
final isAutoNavigatingProvider = StateProvider<bool>((ref) => false);
final navigationAutoProgressProvider = StateProvider<double>((ref) => 0.0);
final shouldFollowNavigationProvider = StateProvider<bool>((ref) => true);

// Live navigation data
final navigationProgressProvider =
    StateProvider<NavigationProgress?>((ref) => null);
final liveDistanceProvider = StateProvider<double?>((ref) => null);
final navigationStepsProvider = StateProvider<List<String>>((ref) => []);
final currentStepIndexProvider = StateProvider<int>((ref) => 0);
final isNavigatingProvider = StateProvider<bool>((ref) => false);
final selectedTravelModeProvider =
    StateProvider<TravelMode>((ref) => TravelMode.walking);
final routeDataProvider = StateProvider<RouteResult?>((ref) => null);
final polylinesProvider = StateProvider<Map<PolylineId, Polyline>>((ref) => {});
final selectedDestinationProvider = StateProvider<LatLng?>((ref) => null);

final routeServiceProvider = Provider<RouteService>((ref) {
  return RouteService();
});

final currentLocationProvider = FutureProvider<LatLng?>((ref) async {
  final locationService = ref.read(locationServiceProvider);
  return await locationService.getCurrentLocation();
});

final markersProvider =
    StateNotifierProvider<MarkersNotifier, Set<Marker>>((ref) {
  return MarkersNotifier();
});

final mapControllerProvider =
    StateProvider<GoogleMapController?>((ref) => null);

final mapTypeProvider = StateProvider<MapType>((ref) => MapType.normal);

class MarkersNotifier extends StateNotifier<Set<Marker>> {
  MarkersNotifier() : super({});

  final Map<String, Marker> _markersMap = {};

  void addMarker(LatLng position, String markerId, {String? title}) {
    final marker = Marker(
      markerId: MarkerId(markerId),
      position: position,
      infoWindow: InfoWindow(title: title ?? markerId),
    );

    _markersMap[markerId] = marker;
    state = Set.from(_markersMap.values);
  }

  void removeMarker(String markerId) {
    if (_markersMap.remove(markerId) != null) {
      state = Set.from(_markersMap.values);
    }
  }

  void clearMarkers() {
    print("Clear marker=================>");
    _markersMap.clear();
    state = {};
  }

  // Add this method to clear specific markers
  void clearSpecificMarker(String markerId) {
    if (_markersMap.remove(markerId) != null) {
      state = Set.from(_markersMap.values);
    }
  }

  void addMarkers(List<({LatLng position, String id, String? title})> markers) {
    for (final markerData in markers) {
      final marker = Marker(
        markerId: MarkerId(markerData.id),
        position: markerData.position,
        infoWindow: InfoWindow(title: markerData.title ?? markerData.id),
      );
      _markersMap[markerData.id] = marker;
    }
    state = Set.from(_markersMap.values);
  }
}

class NavigationProgress {
  final double distanceRemaining;
  final double distanceTraveled;
  final Duration timeElapsed;
  final Duration estimatedTimeRemaining;
  final double averageSpeed; // km/h

  NavigationProgress({
    required this.distanceRemaining,
    required this.distanceTraveled,
    required this.timeElapsed,
    required this.estimatedTimeRemaining,
    required this.averageSpeed,
  });
}
