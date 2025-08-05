import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:maps_flutter/map/constants/map_constants.dart';

import 'marker_icon.dart';

class MapsScreens extends StatefulWidget {
  const MapsScreens({super.key});

  @override
  State<MapsScreens> createState() => _MapsScreensState();
}

class _MapsScreensState extends State<MapsScreens> {
  bool isSearching = false;
  TextEditingController searchController = TextEditingController();
  CameraPosition? _intialCameraPosition;
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  List<LatLng> polylineCoordinates = [];
  PolylinePoints polylinePoints = PolylinePoints(apiKey: MapConstants.apiKey);
  LatLng? currentLatLng;
  LatLng? destinationLatLng;
  BitmapDescriptor? liveLocationMarker;
  late GoogleMapController mapController;
GetPlaces getPlaces=GetPlaces();
  @override
  void initState() {
    _determinePosition();
    super.initState();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isSearching
          ? AppBar(
              backgroundColor: Colors.greenAccent,
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    isSearching = false;
                    searchController.clear();
                  });
                },
              ),
              title: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: "Search here...",
                ),
                onChanged: (String e) {},
              ),
            )
          : AppBar(
              backgroundColor: Colors.greenAccent,
              centerTitle: true,
              title: Text("Live Tracking"),
              actions: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      isSearching = true;
                    });
                  },
                  icon: const Icon(Icons.search),
                ),
              ],
            ),
      body: currentLatLng == null
          ? Center(
              child: CircularProgressIndicator(
                color: Colors.greenAccent,
              ),
            )
          : GoogleMap(
              // initialCameraPosition: CameraPosition(target: LatLng(22.577152,88.4309163),zoom:14),
              initialCameraPosition: _intialCameraPosition!,
              mapType: MapType.normal,
              myLocationEnabled: true,
              compassEnabled: true,
              scrollGesturesEnabled: true,
              zoomControlsEnabled: false
        ,
              markers: markers,
              polylines: polylines,
              onMapCreated: (GoogleMapController controller) {
                mapController=controller;
              },
            ),
      floatingActionButton: FloatingActionButton(onPressed: (){
        mapController.animateCamera(CameraUpdate.newLatLngZoom(currentLatLng!,16));
      },child: Icon(Icons.my_location_outlined),),
    );
  }

  final GeolocatorPlatform _geolocatorPlatform = GeolocatorPlatform.instance;

  void _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await _geolocatorPlatform.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await _geolocatorPlatform.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _geolocatorPlatform.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }
    late LocationSettings locationSettings;

    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 4,
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 10),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText:
              "Example app will continue to receive your location even when you aren't using it",
          notificationTitle: "Running in Background",
          enableWakeLock: false,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.fitness,
        distanceFilter: 4,
        pauseLocationUpdatesAutomatically: true,
        showBackgroundLocationIndicator: false,
      );
    } else {
      locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100,
      );
    }
    await getBytesFromAsset('assets/pngs/profile.png', 100).then((value) {
      setState(() {
        liveLocationMarker = value;
      });
    });
    _geolocatorPlatform
        .getPositionStream(locationSettings: locationSettings)
        .listen((Position? position) {
      print(position == null
          ? 'Unknown'
          : '${position.latitude.toString()}, ${position.longitude.toString()}');

      currentLatLng = LatLng(position!.latitude, position.longitude);
      _intialCameraPosition = CameraPosition(
        target: currentLatLng!,
        zoom: 15,
      );
      markers.removeWhere((e) => e.mapsId.value.compareTo("origin") == 0);
      markers.add(Marker(
          markerId: MarkerId("origin"),
          infoWindow: InfoWindow(title: "You are here"),
          position: currentLatLng!,
          icon: liveLocationMarker!));

      setState(() {});
    });
  }
}

class GetPlaces {
}
