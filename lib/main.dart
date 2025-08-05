import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maps_flutter/google_maps/maps_screens.dart';

// Api Key
// AIzaSyBs_mYBIEbsXXH_lnqrp5bx04CpVlK89rE
void main() {
  // WidgetsFlutterBinding.ensureInitialized();
  runApp(ProviderScope(child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false, home: Scaffold(body: MapsScreens()));
  }
}
