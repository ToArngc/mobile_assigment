import 'package:flutter/material.dart';

import '../../../models/station.dart';
import 'live_route_map.dart';
import 'station_detail_page.dart';

class LiveMapPage extends StatelessWidget {
  const LiveMapPage({required this.stations, super.key});
  final List<Station> stations;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('KTM route map')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'Live train positions',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Current train locations are projected onto the route schematic.',
            ),
            const SizedBox(height: 18),
            Expanded(
              child: Center(
                child: LiveRouteMap(
                  stations: stations,
                  line: 'Port Klang Line',
                  onStationTap: (station) => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => StationDetailPage(station: station),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      );
}
