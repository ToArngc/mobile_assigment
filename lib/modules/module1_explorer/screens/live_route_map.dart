import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/station.dart';
import '../../../models/train_status.dart';
import '../../../services/station_repository.dart';

/// Route overview for Explore. Supply stations in their GTFS stop sequence.
class LiveRouteMap extends StatefulWidget {
  const LiveRouteMap({
    required this.stations,
    required this.onStationTap,
    required this.line,
    this.compact = false,
    this.onExpand,
    super.key,
  });

  final List<Station> stations;
  final ValueChanged<Station> onStationTap;
  final String line;
  final bool compact;
  final VoidCallback? onExpand;

  @override
  State<LiveRouteMap> createState() => _LiveRouteMapState();
}

class _LiveRouteMapState extends State<LiveRouteMap> {
  late Future<List<TrainStatus>> _trainStatusFuture;

  @override
  void initState() {
    super.initState();
    _trainStatusFuture = StationRepository().getLatestTrainStatus(line: widget.line);
  }

  @override
  void didUpdateWidget(covariant LiveRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.line != widget.line) {
      _trainStatusFuture = StationRepository().getLatestTrainStatus(line: widget.line);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stations.length < 2) return const _MapUnavailable();
    final height = widget.compact ? 176.0 : 310.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: ColoredBox(
        color: const Color(0xffe8f4fd),
        child: SizedBox(
          height: height,
          child: LayoutBuilder(builder: (context, constraints) {
            final points = _routePoints(
              widget.stations.length,
              constraints.biggest,
              widget.compact,
            );
            return FutureBuilder<List<TrainStatus>>(
              future: _trainStatusFuture,
              builder: (context, snapshot) => Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: _RoutePainter(points))),
                  ...List.generate(widget.stations.length, (index) => Positioned(
                    left: points[index].dx - 8,
                    top: points[index].dy - 8,
                    child: GestureDetector(
                      onTap: () => widget.onStationTap(widget.stations[index]),
                      child: Tooltip(
                        message: widget.stations[index].name,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xff1267a9),
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )),
                  ...List.generate(widget.stations.length, (index) => Positioned(
                    left: math.max(6, points[index].dx - 35),
                    top: points[index].dy + 14,
                    width: 70,
                    child: Text(
                      widget.stations[index].name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff36565d),
                      ),
                    ),
                  ),
                  )),
                  ..._trainMarkers(snapshot.data ?? const <TrainStatus>[], points),
                  Positioned(
                    top: 10,
                    left: 12,
                    child: Text(
                      widget.line,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xff1a4f78),
                          ),
                    ),
                  ),
                  if (widget.onExpand != null)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: IconButton(
                        onPressed: widget.onExpand,
                        tooltip: 'Open full route map',
                        icon: const Icon(Icons.open_in_full, size: 19),
                      ),
                    ),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Positioned(right: 12, bottom: 8, child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)))
                  else if (snapshot.hasError)
                    const Positioned(left: 12, bottom: 8, child: Text('Live positions are unavailable', style: TextStyle(fontSize: 9, color: Color(0xff36565d))))
                  else if ((snapshot.data ?? const <TrainStatus>[]).where((status) => status.lat != null && status.lng != null).isEmpty)
                    const Positioned(left: 12, bottom: 8, child: Text('No live positions reported', style: TextStyle(fontSize: 9, color: Color(0xff36565d)))),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  List<Offset> _routePoints(int count, Size size, bool compact) {
    const padding = 26.0;
    final y = compact ? 74.0 : size.height / 2;
    final width = size.width - (padding * 2);
    return List.generate(
      count,
      (index) => Offset(padding + (width * index / (count - 1)), y),
    );
  }

  List<Widget> _trainMarkers(List<TrainStatus> statuses, List<Offset> points) {
    return statuses
        .where((status) => status.lat != null && status.lng != null)
        .map((status) => _TrainMarker(
              point: _projectToRoute(status.lat!, status.lng!, points),
              label: status.line,
            ))
        .toList();
  }

  /// Projects a real 2-D coordinate onto the nearest station-to-station
  /// segment, then uses that fraction on the one-dimensional schematic.
  Offset _projectToRoute(double lat, double lng, List<Offset> points) {
    var nearestPoint = points.first;
    var nearestDistance = double.infinity;
    for (var index = 0; index < widget.stations.length - 1; index++) {
      final start = widget.stations[index];
      final end = widget.stations[index + 1];
      final deltaLat = end.lat - start.lat;
      final deltaLng = end.lng - start.lng;
      final lengthSquared = (deltaLat * deltaLat) + (deltaLng * deltaLng);
      final rawFraction = lengthSquared == 0
          ? 0.0
          : (((lat - start.lat) * deltaLat) + ((lng - start.lng) * deltaLng)) / lengthSquared;
      final fraction = rawFraction.clamp(0.0, 1.0).toDouble();
      final projectedLat = start.lat + (deltaLat * fraction);
      final projectedLng = start.lng + (deltaLng * fraction);
      final distance = ((lat - projectedLat) * (lat - projectedLat)) + ((lng - projectedLng) * (lng - projectedLng));
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestPoint = Offset.lerp(points[index], points[index + 1], fraction)!;
      }
    }
    return nearestPoint;
  }
}

class _TrainMarker extends StatelessWidget {
  const _TrainMarker({required this.point, required this.label});
  final Offset point;
  final String label;

  @override
  Widget build(BuildContext context) => Positioned(
        left: point.dx - 13,
        top: point.dy - 34,
        child: Tooltip(
          message: 'Live train · $label',
          child: const CircleAvatar(
            radius: 13,
            backgroundColor: Color(0xff006874),
            child: Icon(Icons.train, color: Colors.white, size: 16),
          ),
        ),
      );
}

class _RoutePainter extends CustomPainter {
  const _RoutePainter(this.points);
  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xff1267a9)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) => oldDelegate.points != points;
}

class _MapUnavailable extends StatelessWidget {
  const _MapUnavailable();

  @override
  Widget build(BuildContext context) => Container(
        height: 150,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xffe8f4fd),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Text('Route stops are not available yet.'),
      );
}
