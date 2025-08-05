import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:maps_flutter/map/services/navigation_controller.dart';
import '../providers/providers.dart';
import '../widgets/map_search_bar.dart';
import '../widgets/map_status_widget.dart';

class MapGoogle extends ConsumerStatefulWidget {
  const MapGoogle({super.key});

  @override
  ConsumerState<MapGoogle> createState() => _MapGoogleState();
}

class _MapGoogleState extends ConsumerState<MapGoogle>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final String markerIcon = 'assets/svgs/marker.svg';
  final String profileIcon = 'assets/pngs/profile.png';
  StreamSubscription<LatLng>? _locationSubscription;
  final double _geoFenceRadius = 200;
  StreamSubscription<LatLng>? _navigationSubscription;
  LatLng? _currentNavigationPosition;
  Marker? _navigationMarker;
  final double _navigationStepDistance = 10.0;
  late AnimationController _animationController;
  LatLng? _currentAnimatedPosition;
  Marker? _animatedMarker;
  BitmapDescriptor? _movingMarkerIcon;

  double _calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * (math.pi / 180);
    final lon1 = start.longitude * (math.pi / 180);
    final lat2 = end.latitude * (math.pi / 180);
    final lon2 = end.longitude * (math.pi / 180);

    final y = math.sin(lon2 - lon1) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(lon2 - lon1);
    return (math.atan2(y, x) * (180 / math.pi));
  }

  Future<List<LatLng>> _getRouteCoordinates(LatLng start, LatLng end) async {
    final routeService = ref.read(routeServiceProvider);
    final result = await routeService.getRouteCoordinates(start, end);
    return result.coordinates;
  }

  Future<BitmapDescriptor> _getCustomMovingMarkerIcon() async {
    return await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/images/navigation_marker.png',
    );
  }

  void _updateMovingMarker(LatLng newPosition) {
    if (_navigationMarker == null) return;

    double bearing = 0;
    if (_currentNavigationPosition != null) {
      bearing = _calculateBearing(_currentNavigationPosition!, newPosition);
    }

    _navigationMarker = _navigationMarker!.copyWith(
      positionParam: newPosition,
      rotationParam: bearing,
    );
    ref.read(navigationMarkerProvider.notifier).state = _navigationMarker;
  }

  void _stopAutoNavigation() {
    _navigationSubscription?.cancel();
    _navigationSubscription = null;
    ref.read(isAutoNavigatingProvider.notifier).state = false;
    ref.read(navigationMarkerProvider.notifier).state = null;
    _currentNavigationPosition = null;
  }

  Future<void> _startAutoNavigation(LatLng destination) async {
    final currentLocation = ref.read(currentLocationProvider).value;
    if (currentLocation == null) return;

    _stopAutoNavigation();

    await _calculateAndDisplayRoute(currentLocation, destination);

    final polyline = ref.read(polylinesProvider).values.firstOrNull;
    if (polyline == null || polyline.points.isEmpty) {
      _showErrorSnackBar('No valid route found');
      return;
    }

    ref.read(isAutoNavigatingProvider.notifier).state = true;

    _navigationMarker = Marker(
      markerId: const MarkerId('moving_marker'),
      position: currentLocation,
      icon: await _getCustomMovingMarkerIcon(),
      anchor: const Offset(0.5, 0.5),
      rotation: 0,
    );
    ref.read(navigationMarkerProvider.notifier).state = _navigationMarker;

    final streamController = StreamController<LatLng>();
    _navigationSubscription =
        streamController.stream.listen(_handlePositionUpdate);

    unawaited(Isolate.run(() => _simulateMovement(
          streamController,
          polyline.points,
        )));
  }

  void _handlePositionUpdate(LatLng newPosition) {
    _currentNavigationPosition = newPosition;
    _updateMovingMarker(newPosition);

    if (ref.read(shouldFollowNavigationProvider)) {
      _mapController?.animateCamera(CameraUpdate.newLatLng(newPosition));
    }
  }

  Future<void> _simulateMovement(
      StreamController<LatLng> controller, List<LatLng> route) async {
    for (int i = 0; i < route.length - 1; i++) {
      final start = route[i];
      final end = route[i + 1];
      final distance = _calculateDistance(start, end);
      final steps = (distance / _navigationStepDistance).ceil();

      for (int step = 0; step < steps; step++) {
        final ratio = step / steps;
        final lat = start.latitude + (end.latitude - start.latitude) * ratio;
        final lng = start.longitude + (end.longitude - start.longitude) * ratio;

        controller.add(LatLng(lat, lng));
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    controller.add(route.last);
    controller.close();
  }

  void _addGeoFenceCircle(LatLng center, double radius) {
    ref.read(geofenceCircleProvider.notifier).state = {
      Circle(
        circleId: const CircleId('geo_fence'),
        center: center,
        radius: radius,
        strokeWidth: 2,
        strokeColor: Colors.green,
        fillColor: Colors.green.withOpacity(0.15),
      ),
    };
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

  Future<void> _addDestinationMarkerWithAnimation(LatLng position) async {
    // Add destination marker
    ref.read(markersProvider.notifier).addMarker(
          position,
          "destination",
          title: "Destination",
        );

    ref.read(selectedDestinationProvider.notifier).state = position;

    await _fitCameraToBounds([
      ref.read(currentLocationProvider).value!,
      position,
    ]);
    _addGeoFenceCircle(position, _geoFenceRadius);
  }

  Future<void> _fitCameraToBounds(List<LatLng> points) async {
    if (points.isEmpty || _mapController == null) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLon = points.first.longitude;
    double maxLon = points.first.longitude;

    for (LatLng point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLon = math.min(minLon, point.longitude);
      maxLon = math.max(maxLon, point.longitude);
    }

    double padding = 0.01;

    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - padding, minLon - padding),
          northeast: LatLng(maxLat + padding, maxLon + padding),
        ),
        100.0, // Padding in pixels
      ),
    );
  }

  Future<void> _calculateAndDisplayRoute(
      LatLng origin, LatLng destination) async {
    int retryCount = 0;
    const int maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        final routeService = ref.read(routeServiceProvider);
        final result = await routeService.getRouteCoordinates(
          origin,
          destination,
          timeout: const Duration(seconds: 15),
        );

        if (result.hasError) {
          throw Exception(result.errorMessage!);
        }

        if (!result.isEmpty) {
          final polyline = routeService.createPolyline(result.coordinates);
          _addPolylineToMap(polyline);

          await _fitCameraToBounds(result.coordinates);

          _showSuccessSnackBar();
          return;
        } else {
          throw Exception('No route found');
        }
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          _showErrorSnackBar(
              'Failed to calculate route after $maxRetries attempts: $e');
          _clearRoute();
          return;
        }

        await Future.delayed(Duration(seconds: retryCount));
      }
    }
  }

  void _handleMapLongPress(LatLng position) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.directions),
              title: const Text('Get Directions'),
              onTap: () {
                Navigator.pop(context);
                _handleMapTap(position);
              },
            ),
            ListTile(
              leading: const Icon(Icons.place),
              title: const Text('Add Marker'),
              onTap: () {
                Navigator.pop(context);
                _addRegularMarker(position);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('What\'s here?'),
              onTap: () {
                Navigator.pop(context);
                _showLocationInfo(position);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationInfo(LatLng position) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}'),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    );
    _loadMarkerIcon();
  }

  Future<void> _loadMarkerIcon() async {
    _movingMarkerIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(10, 10)),
      'assets/images/navigation_marker.png', // Your marker image
    );
    _locationSubscription = ref
        .read(locationServiceProvider)
        .getLocationStream()
        .listen((LatLng newLoc) {
      final destination = ref.read(selectedDestinationProvider);
      if (destination != null) {
        final distance = _calculateDistance(newLoc, destination);
        ref.read(liveDistanceProvider.notifier).state = distance;
        if (distance < _geoFenceRadius) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You reached the destination!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _stopAutoNavigation();
    _mapController?.dispose();
    _locationSubscription?.cancel();
    _mapController?.dispose();
    final navigationController = ref.read(navigationControllerProvider);
    navigationController.dispose();
    _mapController?.dispose();
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var liveDistance = ref.watch(liveDistanceProvider);
    final currentLocation = ref.watch(currentLocationProvider);
    final markers = ref.watch(markersProvider);
    final mapType = ref.watch(mapTypeProvider);
    final polylines = ref.watch(polylinesProvider);
    final isNavigating = ref.watch(isInNavigationModeProvider);
    final destination = ref.watch(selectedDestinationProvider);

    // void _onStartNavigationPressed() {
    //   final destination = ref.read(selectedDestinationProvider);
    //   if (destination != null) {
    //     _startMockNavigation(destination);
    //   }
    // }

    return Scaffold(
      body: Stack(
        children: [
          // Main Map
          currentLocation.when(
            data: (location) =>
                _buildMap(location, markers, mapType, polylines),
            error: (_, __) => MapErrorWidget(
              onRetry: () => ref.refresh(currentLocationProvider),
            ),
            loading: () => const MapLoadingWidget(),
          ),
          // Search Bar
          MapSearchBar(
            markerIcon: markerIcon,
            profileIcon: profileIcon,
            onSearchTap: () => _handleSearchTap(),
            onMicTap: () => _handleMicTap(),
            onProfileTap: () => _handleProfileTap(),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            right: 16,
            child: _buildMapTypeButton(),
          ),
          if (liveDistance != null && !isNavigating)
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.94),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          blurRadius: 8,
                          color: Colors.black12,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Text(
                    'Distance to destination: ${(liveDistance / 1000).toStringAsFixed(2)} km',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87),
                  ),
                ),
              ),
            )
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 58.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (isNavigating)
              FloatingActionButton(
                mini: true,
                heroTag: 'stop_nav',
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 4,
                onPressed: () {
                  final navigationController =
                      ref.read(navigationControllerProvider); 
                  navigationController.stopNavigation();
                },
                child: const Icon(Icons.stop),
              ),
            if (isNavigating) const SizedBox(height: 10),
            FloatingActionButton(
              mini: true,
              heroTag: 'clear',
              backgroundColor: Colors.white,
              foregroundColor: Colors.red,
              elevation: 4,
              onPressed: _handleClearAll,
              child: const Icon(Icons.clear_all),
            ),
            const SizedBox(height: 10),
            FloatingActionButton(
              heroTag: 'location',
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue,
              elevation: 4,
              onPressed: _handleGoToCurrentLocation,
              child: const Icon(Icons.my_location),
            ),
            if (ref.watch(selectedDestinationProvider) != null &&
                !ref.watch(isAutoNavigatingProvider))
              FloatingActionButton(
                onPressed: () => _startAutoNavigation(
                    ref.read(selectedDestinationProvider)!),
                child: const Icon(Icons.navigation),
              ),
          ],
        ),
      ),
    );
  }

  List<LatLng> _generateMockRoutePoints(
      LatLng start, LatLng end, int segments) {
    final points = <LatLng>[];
    for (int i = 0; i <= segments; i++) {
      final ratio = i / segments;
      points.add(LatLng(
        start.latitude + (end.latitude - start.latitude) * ratio,
        start.longitude + (end.longitude - start.longitude) * ratio,
      ));
    }
    return points;
  }

  Widget _buildMap(LatLng? location, Set<Marker> markers, MapType mapType,
      Map<PolylineId, Polyline> polylines) {
    return GoogleMap(
      onMapCreated: _onMapCreated,
      mapType: mapType,
      initialCameraPosition: CameraPosition(
        target: location ?? const LatLng(22.580434, 88.4351664),
        zoom: 15.0,
      ),
      markers: {
        ...markers,
        if (ref.watch(navigationMarkerProvider) != null)
          ref.watch(navigationMarkerProvider)!,
      },
      polylines: Set<Polyline>.of(polylines.values),
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      compassEnabled: true,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      rotateGesturesEnabled: true,
      scrollGesturesEnabled: true,
      tiltGesturesEnabled: true,
      zoomGesturesEnabled: true,
      onTap: _handleMapTap,
      onLongPress: _handleMapLongPress,
    );
  }

  Widget _buildMapTypeButton() {
    final mapType = ref.watch(mapTypeProvider);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          mapType == MapType.normal ? Icons.layers : Icons.map,
          color: Colors.black87,
        ),
        tooltip: 'Map Type',
        onPressed: _handleToggleMapType,
      ),
    );
  }

  // Event Handlers
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    ref.read(mapControllerProvider.notifier).state = controller;

    final location = ref.read(currentLocationProvider).value;
    if (location != null) {
      ref.read(markersProvider.notifier).addMarker(
            location,
            "current_location",
            title: "You are here",
          );
    }
  }

  void _handleMapTap(LatLng position) async {
    final currentLocation = ref.read(currentLocationProvider).value;

    if (currentLocation == null) {
      _showErrorSnackBar('Current location not available. Please enable GPS.');
      return;
    }

    final distance = _calculateDistance(currentLocation, position);
    if (distance < 50) {
      // Less than 50 meters
      _showErrorSnackBar('Destination too close to current location');
      return;
    }

    _clearRoute();
    _showCalculatingSnackBar();

    await _addDestinationMarkerWithAnimation(position);

    await _calculateAndDisplayRoute(currentLocation, position);
  }

  void _addRegularMarker(LatLng position) {
    ref.read(markersProvider.notifier).addMarker(
          position,
          "marker_${DateTime.now().millisecondsSinceEpoch}",
          title: "Custom Marker",
        );
  }

  void _addPolylineToMap(Polyline polyline) {
    final currentPolylines = {...ref.read(polylinesProvider)};
    currentPolylines[polyline.polylineId] = polyline;
    ref.read(polylinesProvider.notifier).state = currentPolylines;

    debugPrint(
        'Added polyline: ${polyline.polylineId.value} with ${polyline.points.length} points');
  }

  void _clearRoute({bool clearNavigation = true, bool clearPolylines = false}) {
    if (clearNavigation) {
      final navigationController = ref.read(navigationControllerProvider);
      navigationController.stopNavigation();
      ref.read(isAutoNavigatingProvider.notifier).state = false;
      ref.read(navigationMarkerProvider.notifier).state = null;
      _currentNavigationPosition = null;
    }

    ref.read(selectedDestinationProvider.notifier).state = null;
    ref.read(markersProvider.notifier).clearSpecificMarker("destination");
    ref.read(geofenceCircleProvider.notifier).state = {};

    if (clearPolylines) {
      ref.read(polylinesProvider.notifier).state = {};
    } else {
      // Just clear the navigation-specific polyline if it exists
      final currentPolylines = {...ref.read(polylinesProvider)};
      currentPolylines.removeWhere((key, value) => key.value == 'navigation');
      ref.read(polylinesProvider.notifier).state = currentPolylines;
    }
  }

  void _handleClearAll() {
    ref.read(markersProvider.notifier).clearMarkers();
    ref.read(liveDistanceProvider.notifier).state = null;
    _clearRoute();
  }

  void _handleToggleMapType() {
    final currentType = ref.read(mapTypeProvider);
    ref.read(mapTypeProvider.notifier).state =
        currentType == MapType.normal ? MapType.satellite : MapType.normal;
  }

  void _handleGoToCurrentLocation() async {
    if (_mapController == null) return;

    _showGettingLocationSnackBar();

    final locationService = ref.read(locationServiceProvider);
    final location = await locationService.getCurrentLocation();

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (location != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: location, zoom: 17.0),
        ),
      );
      ref
          .read(markersProvider.notifier)
          .addMarker(location, "current_location", title: "You are here");
      _showLocationFoundSnackBar();
    } else {
      _showLocationErrorSnackBar();
    }
  }

  void _handleSearchTap() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Search functionality coming soon!')),
    );
  }

  void _handleMicTap() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Voice search coming soon!')),
    );
  }

  void _handleProfileTap() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile functionality coming soon!')),
    );
  }

  void _showCalculatingSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            const Text('Calculating best route...'),
          ],
        ),
        duration: const Duration(seconds: 10),
        // Longer duration for route calculation
        backgroundColor: Colors.blue[600],
      ),
    );
  }

  void _showSuccessSnackBar() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 16),
            const Text('Route calculated successfully!'),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String error) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $error'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showGettingLocationSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 16),
            Text('Getting location...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showLocationFoundSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 1),
        backgroundColor: Colors.green,
        content: Row(
          children: [
            Icon(Icons.check, color: Colors.white),
            SizedBox(width: 16),
            Text('Location found!'),
          ],
        ),
      ),
    );
  }

  void _showLocationErrorSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.red,
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 16),
            Text('Could not get location'),
          ],
        ),
      ),
    );
  }
}
