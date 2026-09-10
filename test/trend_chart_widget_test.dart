import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:mobile_assigment/modules/reliability/widgets/trend_chart_widget.dart';
import 'package:mobile_assigment/services/reliability_repository.dart';

List<DailyOnTimeStat> _statsForDays(int count) {
  return List.generate(
    count,
    (i) => DailyOnTimeStat(
      date: DateTime(2026, 9, 1 + i),
      onTimeCount: 8,
      totalCount: 10,
    ),
  );
}

Future<int> _plottedPointCount(WidgetTester tester) async {
  final chartData = tester.widget<LineChart>(find.byType(LineChart)).data;
  return chartData.lineBarsData.single.spots.length;
}

void main() {
  for (final days in [3, 6, 11]) {
    testWidgets('caption matches plotted point count for a $days-day series', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TrendChartWidget(stats: _statsForDays(days))),
        ),
      );

      final plottedPoints = await _plottedPointCount(tester);
      expect(plottedPoints, days);
      expect(find.text('$days-day trend'), findsOneWidget);
    });
  }

  testWidgets('caption tracks the new series when the line filter changes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TrendChartWidget(stats: _statsForDays(7))),
      ),
    );
    expect(find.text('7-day trend'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TrendChartWidget(stats: _statsForDays(4))),
      ),
    );

    final plottedPoints = await _plottedPointCount(tester);
    expect(plottedPoints, 4);
    expect(find.text('4-day trend'), findsOneWidget);
    expect(find.text('7-day trend'), findsNothing);
  });
}
