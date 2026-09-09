import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_assigment/models/station.dart';
import 'package:mobile_assigment/modules/module1_explorer/screens/explorer_home_page.dart';
import 'package:mobile_assigment/modules/module1_explorer/screens/live_route_map.dart';

void main() {
  test('Station parses multiple line labels for an interchange', () {
    final station = Station.fromJson({
      'id': 'kl-sentral',
      'name': 'KL Sentral',
      'line': 'Port Klang Line / Seremban Line',
      'lat': 3.134,
      'lng': 101.686,
    });

    expect(station.lines, ['Port Klang Line', 'Seremban Line']);
  });

  testWidgets('Route map shows a clear state when fewer than two stops exist', (
    tester,
  ) async {
    final station = Station(
      id: 'kl-sentral',
      name: 'KL Sentral',
      line: 'Port Klang Line',
      lat: 3.134,
      lng: 101.686,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveRouteMap(
            stations: [station],
            line: station.line,
            onStationTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Route stops are not available yet.'), findsOneWidget);
  });

  testWidgets('changing map line sends only matching stations to the map', (
    tester,
  ) async {
    final stations = [
      Station(
        id: 'port-klang',
        name: 'Pelabuhan Klang',
        line: 'Port Klang Line',
        lat: 3.0,
        lng: 101.4,
      ),
      Station(
        id: 'kl-sentral',
        name: 'KL Sentral',
        line: 'Port Klang Line / Seremban Line',
        lat: 3.1,
        lng: 101.6,
      ),
      Station(
        id: 'seremban',
        name: 'Seremban',
        line: 'Seremban Line',
        lat: 2.7,
        lng: 101.9,
      ),
    ];
    String? mappedLine;
    List<Station> mappedStations = const [];

    await tester.pumpWidget(
      MaterialApp(
        home: ExplorerHomePage(
          loadStations: () async => stations,
          liveMapBuilder:
              ({
                required stations,
                required line,
                required onStationTap,
                required onExpand,
              }) {
                mappedLine = line;
                mappedStations = stations;
                return Text('Map for $line');
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(mappedLine, 'Port Klang Line');
    expect(
      mappedStations.map((station) => station.id),
      containsAll(<String>['port-klang', 'kl-sentral']),
    );
    expect(mappedStations, hasLength(2));

    await tester.tap(find.text('Live train positions'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seremban Line').last);
    await tester.pumpAndSettle();

    expect(mappedLine, 'Seremban Line');
    expect(
      mappedStations.map((station) => station.id),
      containsAll(<String>['kl-sentral', 'seremban']),
    );
    expect(mappedStations, hasLength(2));
  });
}
