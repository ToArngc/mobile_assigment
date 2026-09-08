import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants.dart';
import '../../../core/line_colors.dart';
import '../../../core/theme.dart';
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
    if (oldWidget.line != widget.line || oldWidget.stations != widget.stations) {
      setState(() => _liveStatuses = _load());
    }
  }

  Future<List<TrainStatus>> _load() {
    if (widget.stations.length < 2 || widget.line.trim().isEmpty) {
      return Future.value(const <TrainStatus>[]);
    }
    return _repository.getLiveTrainStatusForLine(widget.line);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stations.length < 2) return const _MapUnavailable();
    final height = widget.compact ? 176.0 : 360.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        height: height,
        child: FutureBuilder<List<TrainStatus>>(
          future: _liveStatuses,
          builder: (context, snapshot) {
            final stations = widget.stations;
            final stationsById = {for (final station in stations) station.id: station};
            final trainStatuses = snapshot.data
                    ?.where((status) => status.lat != null && status.lng != null)
                    .toList() ??
                const <TrainStatus>[];
            final routeColor = lineColor(widget.line);

            return Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(stations.first.lat, stations.first.lng),
                    zoom: 11,
                  ),
                  onMapCreated: (controller) => _fitRoute(controller, stations),
                  markers: {
                    for (final station in stations)
                      Marker(
                        markerId: MarkerId('station-${station.id}'),
                        position: LatLng(station.lat, station.lng),
                        infoWindow: InfoWindow(
                          title: station.name,
                          snippet: station.line,
                        ),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueAzure,
                        ),
                        onTap: () => widget.onStationTap(station),
                      ),
                    for (final status in trainStatuses)
                      Marker(
                        markerId: MarkerId('train-${status.id}'),
                        position: LatLng(status.lat!, status.lng!),
                        infoWindow: InfoWindow(
                          title: 'Live train',
                          snippet: stationsById[status.stationId]?.name ?? widget.line,
                        ),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueGreen,
                        ),
                      ),
                  },
                  polylines: {
                    Polyline(
                      polylineId: PolylineId('route-${widget.line}'),
                      points: [
                        for (final station in stations) LatLng(station.lat, station.lng),
                      ],
                      color: routeColor,
                      width: 6,
                      jointType: JointType.round,
                    ),
                  },
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: !widget.compact,
                  mapToolbarEnabled: !widget.compact,
                  rotateGesturesEnabled: !widget.compact,
                  scrollGesturesEnabled: !widget.compact,
                  zoomGesturesEnabled: !widget.compact,
                  tiltGesturesEnabled: !widget.compact,
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: _MapLabel(
                    line: widget.line,
                    trainCount: trainStatuses.length,
                    loading: snapshot.connectionState == ConnectionState.waiting,
                  ),
                ),
                if (widget.onExpand != null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: IconButton(
                        onPressed: widget.onExpand,
                        tooltip: 'Open full route map',
                        icon: const Icon(Icons.open_in_full, size: 19),
                      ),
                    ),
                  ),
                if (snapshot.hasError)
                  const Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: _MapNotice('Live train positions are unavailable right now.'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _fitRoute(
    GoogleMapController controller,
    List<Station> stations,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    var south = stations.first.lat;
    var north = stations.first.lat;
    var west = stations.first.lng;
    var east = stations.first.lng;
    for (final station in stations.skip(1)) {
      south = station.lat < south ? station.lat : south;
      north = station.lat > north ? station.lat : north;
      west = station.lng < west ? station.lng : west;
      east = station.lng > east ? station.lng : east;
    }
    if (south == north && west == east) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(south, west), 14),
      );
      return;
    }
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south, west),
          northeast: LatLng(north, east),
        ),
        widget.compact ? 34 : 50,
      ),
    );
  }

}

class _MapLabel extends StatelessWidget {
  const _MapLabel({
    required this.line,
    required this.trainCount,
    required this.loading,
  });

  final String line;
  final int trainCount;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final message = loading
        ? 'Loading live trains…'
        : trainCount == 0
            ? 'No live trains right now'
            : '$trainCount live train${trainCount == 1 ? '' : 's'}';
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              line.isEmpty ? 'KTM route' : line,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
            Text(message, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _MapNotice extends StatelessWidget {
  const _MapNotice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(message, textAlign: TextAlign.center),
        ),
      );
}

class _MapUnavailable extends StatelessWidget {
  const _MapUnavailable();

  @override
  Widget build(BuildContext context) => Container(
        height: 150,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Text('Route stops are not available yet.'),
      );
}
