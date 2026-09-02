import 'package:flutter/material.dart';
import '../modules/alerts/screens/alerts_home_screen.dart';
import '../modules/module1_explorer/screens/explorer_home_page.dart';
import '../modules/reports/screens/reports_home_screen.dart';

/// Shared bottom-navigation shell — matches the 4-tab layout (Explore /
/// Reliability / Reports / Alerts) shown across all four modules' mockups.
///
/// Module 3 (Reports) and Module 4 (Alerts) have real screens wired in.
/// Explore and Reliability are still placeholders — swap
/// `_PlaceholderTab(...)` for each teammate's actual screen widget once it
/// exists. This file lives in `shared_widgets/` so any of the four of you
/// can edit it to plug your module in without touching each other's
/// module folders.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _tabs = [
    _TabSpec(label: 'Explore', icon: Icons.train_outlined, activeIcon: Icons.train),
    _TabSpec(label: 'Reliability', icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart),
    _TabSpec(label: 'Reports', icon: Icons.flag_outlined, activeIcon: Icons.flag),
    _TabSpec(label: 'Alerts', icon: Icons.notifications_outlined, activeIcon: Icons.notifications),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          ExplorerHomePage(),
          _PlaceholderTab(moduleName: 'Module 2 — Reliability Engine'),
          ReportsHomeScreen(),
          AlertsHomeScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: _tabs
            .map((t) => BottomNavigationBarItem(
          icon: Icon(t.icon),
          activeIcon: Icon(t.activeIcon),
          label: t.label,
        ))
            .toList(),
      ),
    );
  }
}

class _TabSpec {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _TabSpec({required this.label, required this.icon, required this.activeIcon});
}

class _PlaceholderTab extends StatelessWidget {
  final String moduleName;
  const _PlaceholderTab({required this.moduleName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(moduleName)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Not built yet — swap this placeholder for the real screen '
                'in app_shell.dart once it exists.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ),
      ),
    );
  }
}
