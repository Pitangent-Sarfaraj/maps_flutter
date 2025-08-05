import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../services/navigation_controller.dart';

class NavigationButton extends ConsumerWidget {
  const NavigationButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNavigating = ref.watch(isInNavigationModeProvider);
    final destination = ref.watch(selectedDestinationProvider);
    final navigationProgress = ref.watch(navigationProgressProvider);

    // Don't show button if no destination is selected
    if (destination == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Navigation progress info (when navigating)
          if (isNavigating && navigationProgress != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildProgressItem(
                        'Distance',
                        '${(navigationProgress.distanceRemaining / 1000).toStringAsFixed(1)} km',
                        Icons.location_on,
                      ),
                      _buildProgressItem(
                        'ETA',
                        _formatDuration(
                            navigationProgress.estimatedTimeRemaining),
                        Icons.access_time,
                      ),
                      _buildProgressItem(
                        'Speed',
                        '${navigationProgress.averageSpeed.toStringAsFixed(1)} km/h',
                        Icons.speed,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: navigationProgress.distanceTraveled /
                        (navigationProgress.distanceTraveled +
                            navigationProgress.distanceRemaining),
                    backgroundColor: Colors.green.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ],
              ),
            ),

          // Start/Stop Navigation Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _handleNavigationToggle(ref),
              icon: Icon(
                isNavigating ? Icons.stop : Icons.navigation,
                color: Colors.white,
              ),
              label: Text(
                isNavigating ? 'Stop Navigation' : 'Start Navigation',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isNavigating ? Colors.red : Colors.blue,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.green.shade600),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.green.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  void _handleNavigationToggle(WidgetRef ref) {
    final isNavigating = ref.read(isInNavigationModeProvider);
    final navigationController = ref.read(  navigationControllerProvider);

    if (isNavigating) {
      navigationController.stopNavigation();
    } else {
      navigationController.startNavigation();
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}
