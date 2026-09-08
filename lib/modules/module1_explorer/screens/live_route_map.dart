import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/station.dart';
import '../../../models/train_status.dart';
import '../../../services/station_repository.dart';














class LiveRouteMap extends StatefulWidget {
  const LiveRouteMap({
    required this.stations,
    required this.line,
    required this.onStationTap,
    this.compact = false,
    this.onExpand,
    super.key,
  });

  final List<Station> stations;
  final String line;
  final ValueChanged<Station> onStationTap;
  final bool compact;
  final VoidCallback? onExpand;

  @override
  State<LiveRouteMap> createState() => _LiveRouteMapState();
}

class _LiveRouteMapState extends State<LiveRouteMap> {
  final StationRepository _repository = StationRepository();
  late Future<List<TrainStatus>> _liveStatuses;

  @override
  void initState() {
    super.initState();
    _liveStatuses = _load();
  }

  @override
  void didUpdateWidget(covariant LiveRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.line != widget.line) {
      setState(() => _liveStatuses = _load());
    }
  }

  Future<List<TrainStatus>> _load() {
    if (widget.line.trim().isEmpty) return Future.value(const <TrainStatus>[]);
    return _repository.getLiveTrainStatusForLine(widget.line);
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
              future: _liveStatuses,
              builder: (context, snapshot) {
                final loading =
                    snapshot.connectionState == ConnectionState.waiting;




                final positions = <double>[];
                if (snapshot.hasData) {
                  for (final status in snapshot.data!) {
                    final index = _trackIndex(status, widget.stations);
                    if (index != null) positions.add(index);
                  }
                }

                return Stack(children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _RoutePainter(points)),
                  ),
                  ...List.generate(
                    widget.stations.length,
                    (index) => Positioned(
                      left: points[index].dx - 8,
                      top: points[index].dy - 8,
                      child: GestureDetector(
                        onTap: () =>
                            widget.onStationTap(widget.stations[index]),
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
                    ),
                  ),
                  ...List.generate(
                    widget.stations.length,
                    (index) => Positioned(
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
                  ),
                  for (final position in positions)
                    _TrainMarker(point: _pointAt(points, position)),
                  Positioned(
                    top: 10,
                    left: 12,
                    child: Text(
                      widget.line.isEmpty ? 'Route' : widget.line,
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
                  Positioned(
                    left: 12,
                    bottom: 8,
                    right: 12,
                    child: Text(
                      _caption(loading, snapshot.hasError, positions.length),
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xff36565d),
                      ),
                    ),
                  ),
                ]);
              },
            );
          }),
        ),
      ),
    );
  }

  String _caption(bool loading, bool hasError, int trainCount) {
    if (loading) return 'Loading live train positions…';
    if (hasError) return 'Live positions unavailable right now.';
    if (trainCount == 0) return 'No live trains on this line right now';
    return trainCount == 1
        ? '1 train currently on this line'
        : '$trainCount trains currently on this line';
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




  double? _trackIndex(TrainStatus status, List<Station> stations) {
    final lat = status.lat;
    final lng = status.lng;
    if (lat == null || lng == null) return null;
    if (stations.length < 2) return null;

    var nearest = 0;
    var nearestDistance = double.infinity;
    for (var i = 0; i < stations.length; i++) {
      final distance =
          _distanceMeters(lat, lng, stations[i].lat, stations[i].lng);
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = i;
      }
    }

    int? neighbour;
    var neighbourDistance = double.infinity;
    for (final candidate in [nearest - 1, nearest + 1]) {
      if (candidate < 0 || candidate >= stations.length) continue;
      final distance = _distanceMeters(
        lat,
        lng,
        stations[candidate].lat,
        stations[candidate].lng,
      );
      if (distance < neighbourDistance) {
        neighbourDistance = distance;
        neighbour = candidate;
      }
    }
    if (neighbour == null) return nearest.toDouble();

    final total = nearestDistance + neighbourDistance;
    if (total <= 0) return nearest.toDouble();
    final fraction = (nearestDistance / total).clamp(0.0, 1.0);
    return nearest + (neighbour - nearest) * fraction;
  }

  double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371000.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _toRadians(double degrees) => degrees * (math.pi / 180);

  Offset _pointAt(List<Offset> points, double index) {
    final clamped = index.clamp(0.0, (points.length - 1).toDouble());
    final before = clamped.floor().clamp(0, points.length - 2);
    return Offset.lerp(points[before], points[before + 1], clamped - before)!;
  }
}

class _TrainMarker extends StatelessWidget {
  const _TrainMarker({required this.point});

  final Offset point;

  @override
  Widget build(BuildContext context) => Positioned(
        left: point.dx - 13,
        top: point.dy - 34,
        child: const CircleAvatar(
          radius: 13,
          backgroundColor: Color(0xff006874),
          child: Icon(Icons.train, color: Colors.white, size: 16),
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
  bool shouldRepaint(covariant _RoutePainter oldDelegate) =>
      oldDelegate.points != points;
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
