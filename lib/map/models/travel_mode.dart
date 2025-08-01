import 'package:flutter/material.dart';

enum TravelMode {
  walking('walking', 'Walking', Icons.directions_walk, Color(0xFF4CAF50)),
  bicycling('bicycling', 'Bicycling', Icons.directions_bike, Color(0xFF2196F3)),
  transit('transit', 'Transit', Icons.directions_bus, Color(0xFFFF9800));

  const TravelMode(this.apiValue, this.displayName, this.icon, this.color);

  final String apiValue;
  final String displayName;
  final IconData icon;
  final Color color;
}