import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MapSearchBar extends StatelessWidget {
  final String markerIcon;
  final String profileIcon;
  final VoidCallback? onSearchTap;
  final VoidCallback? onMicTap;
  final VoidCallback? onProfileTap;

  const MapSearchBar({
    super.key,
    required this.markerIcon,
    required this.profileIcon,
    this.onSearchTap,
    this.onMicTap,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: SvgPicture.asset(
                markerIcon,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: onSearchTap,
                child: const Text(
                  'Search here',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.mic, color: Colors.grey),
              onPressed: onMicTap,
            ),
            GestureDetector(
              onTap: onProfileTap,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[200],
                  image: DecorationImage(
                    image: AssetImage(profileIcon),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
