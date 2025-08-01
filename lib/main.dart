import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'map/presentation/map_google.dart';

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
    return MaterialApp(debugShowCheckedModeBanner: false,home: Scaffold(body: MapGoogle()));
  }
}


