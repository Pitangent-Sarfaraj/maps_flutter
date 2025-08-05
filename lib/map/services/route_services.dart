import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:maps_flutter/map/constants/map_constants.dart';

class RouteResult {
  final List<LatLng> coordinates;
  final String? distance;
  final String? duration;
  final String? errorMessage;

  RouteResult({
    required this.coordinates,
    this.distance,
    this.duration,
    this.errorMessage,
  });

  bool get hasError => errorMessage != null;
  bool get isEmpty => coordinates.isEmpty;
}

class RouteService {
  late final PolylinePoints _polylinePoints;

  RouteService() {
    _polylinePoints = PolylinePoints(apiKey: MapConstants.apiKey);
  }

  Polyline createPolyline(
      List<LatLng> coordinates, {
        String id = 'route',
        Color color = Colors.blue,
        int width = 5,
        bool geodesic = true,
      }) {
    return Polyline(
      polylineId: PolylineId(id),
      color: color,
      points: coordinates,
      width: width,
      geodesic: geodesic,
    );
  }


  Future<RouteResult> getRouteCoordinates(
      LatLng origin,
      LatLng destination, {
        TravelMode travelMode = TravelMode.driving,
        Duration? timeout,
      }) async {
    try {
      final request = PolylineRequest(
        origin: PointLatLng(origin.latitude, origin.longitude),
        destination: PointLatLng(destination.latitude, destination.longitude),
        mode: travelMode,
      );

      PolylineResult result = await _polylinePoints.getRouteBetweenCoordinates(
        request: request,
        timeout: timeout, // USE THE TIMEOUT PARAMETER
      );

      if (result.points.isNotEmpty) {
        List<LatLng> polylineCoordinates = [];
        for (PointLatLng point in result.points) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        }

        return RouteResult(
          coordinates: polylineCoordinates,
        );
      } else {
        return RouteResult(
          coordinates: [],
          errorMessage: result.errorMessage ?? 'No route found',
        );
      }
    } catch (e) {
      return RouteResult(
        coordinates: [],
        errorMessage: 'Failed to calculate route: $e',
      );
    }
  }

}
