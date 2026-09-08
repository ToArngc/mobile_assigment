import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_assigment/models/station.dart';
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

  testWidgets('Route map shows a clear state when fewer than two stops exist',
      (tester) async {
    final station = Station(
      id: 'kl-sentral',
      name: 'KL Sentral',
      line: 'Port Klang Line',
      lat: 3.134,
      lng: 101.686,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LiveRouteMap(
          stations: [station],
          line: station.line,
          onStationTap: (_) {},
        ),
      ),
    ));

    expect(find.text('Route stops are not available yet.'), findsOneWidget);
  });
}
