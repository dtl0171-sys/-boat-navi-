import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';

class RouteInfoBar extends StatelessWidget {
  const RouteInfoBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NavigationProvider>(
      builder: (context, provider, child) {
        if (provider.routeLegs.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xDD0D1F3C),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Total summary row
              Row(
                children: [
                  const Icon(Icons.route, size: 18, color: Color(0xFF00E5FF)),
                  const SizedBox(width: 6),
                  Text(
                    '${provider.totalDistanceKm.toStringAsFixed(1)} km',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.schedule,
                      size: 18, color: Color(0xFF00E5FF)),
                  const SizedBox(width: 4),
                  Text(
                    provider.totalDurationText,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${provider.boatSpeed.toStringAsFixed(0)} ${provider.speedUnitLabel}',
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              if (provider.routeLegs.length > 1) ...[
                Divider(
                    height: 14,
                    color:
                        const Color(0xFF00E5FF).withValues(alpha: 0.15)),
                // Individual legs with dot stepper
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 100),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: provider.routeLegs.map((leg) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF00E5FF),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00E5FF)
                                          .withValues(alpha: 0.5),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${leg.from.displayName} → ${leg.to.displayName}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.white70),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${leg.distanceText} / ${leg.durationText}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: const Color(0xFF00E5FF)
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
