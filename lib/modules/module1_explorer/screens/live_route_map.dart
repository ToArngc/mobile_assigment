import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/station.dart';

/// Route overview for Explore. Supply stations in their GTFS stop sequence.
class LiveRouteMap extends StatefulWidget {
  const LiveRouteMap({
    required this.stations,
    required this.onStationTap,
    this.compact = false,
    this.onExpand,
    super.key,
  });

  final List<Station> stations;
  final ValueChanged<Station> onStationTap;
  final bool compact;
  final VoidCallback? onExpand;

  @override
  State<LiveRouteMap> createState() => _LiveRouteMapState();
}

class _LiveRouteMapState extends State<LiveRouteMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
            return Stack(children: [
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
              )),
              AnimatedBuilder(
                animation: _controller,
                builder: (_, __) => _TrainMarker(
                  point: _pointAt(points, _controller.value),
                ),
              ),
              AnimatedBuilder(
                animation: _controller,
                builder: (_, __) => _TrainMarker(
                  point: _pointAt(points.reversed.toList(), _controller.value),
                  reverse: true,
                ),
              ),
              Positioned(
                top: 10,
                left: 12,
                child: Text(
                  'Port Klang Line',
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
              const Positioned(
                left: 12,
                bottom: 8,
                child: Text(
                  'Preview route · connect GTFS-Realtime for live positions',
                  style: TextStyle(fontSize: 9, color: Color(0xff36565d)),
                ),
              ),
            ]);
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

  Offset _pointAt(List<Offset> points, double progress) {
    final segment = progress * (points.length - 1);
    final before = segment.floor().clamp(0, points.length - 2) as int;
    final after = before + 1;
    return Offset.lerp(points[before], points[after], segment - before)!;
  }
}

class _TrainMarker extends StatelessWidget {
  const _TrainMarker({required this.point, this.reverse = false});
  final Offset point;
  final bool reverse;

  @override
  Widget build(BuildContext context) => Positioned(
        left: point.dx - 13,
        top: point.dy - 34,
        child: Transform.rotate(
          angle: reverse ? math.pi : 0,
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
