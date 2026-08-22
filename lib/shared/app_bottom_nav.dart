import 'package:flutter/material.dart';

import 'app_palette.dart';

/// The four bottom-tab destinations of the app.
enum AppTab { explore, reliability, reports, alerts }

/// Bottom nav bar shared by all four module screens. Wire `onSelect` into
/// your router (e.g. an IndexedStack in main.dart / a PageView) — this
/// widget only renders the bar and reports taps, it doesn't navigate itself.
class AppBottomNav extends StatelessWidget {
  final AppTab active;
  final ValueChanged<AppTab>? onSelect;
  const AppBottomNav({super.key, required this.active, this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          color: AppPalette.card,
          border: Border(top: BorderSide(color: AppPalette.border)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NavItem(
              icon: Icons.directions_railway_outlined,
              label: 'Explore',
              selected: active == AppTab.explore,
              onTap: () => onSelect?.call(AppTab.explore),
            ),
            _NavItem(
              icon: Icons.bar_chart_rounded,
              label: 'Reliability',
              selected: active == AppTab.reliability,
              onTap: () => onSelect?.call(AppTab.reliability),
            ),
            _NavItem(
              icon: Icons.flag_outlined,
              label: 'Reports',
              selected: active == AppTab.reports,
              onTap: () => onSelect?.call(AppTab.reports),
            ),
            _NavItem(
              icon: Icons.notifications_none_rounded,
              label: 'Alerts',
              selected: active == AppTab.alerts,
              onTap: () => onSelect?.call(AppTab.alerts),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const _NavItem({required this.icon, required this.label, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppPalette.teal : AppPalette.subtext;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: color, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
