import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/models/fault_report.dart';
import '../../../core/models/station.dart';
import '../../../shared/app_palette.dart';
import '../repositories/reports_repository.dart' show ReportCategory;


class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppPalette.label,
        letterSpacing: 0.4,
      ),
    );
  }
}

// Station field + picker sheet

class StationField extends StatelessWidget {
  final Station? station;
  final VoidCallback onTap;
  const StationField({super.key, required this.station, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppPalette.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppPalette.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 19, color: AppPalette.teal),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                station?.name ?? 'Select a station',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppPalette.ink),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: AppPalette.subtext),
          ],
        ),
      ),
    );
  }
}

class StationPickerSheet extends StatelessWidget {
  final Station? current;
  final List<Station> stations;
  const StationPickerSheet({super.key, required this.current, required this.stations});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: AppPalette.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Select station',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppPalette.ink)),
            const SizedBox(height: 12),
            if (stations.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator(color: AppPalette.teal)),
              )
            else
              ...stations.map((s) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      s.id == current?.id ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: s.id == current?.id ? AppPalette.teal : AppPalette.subtext,
                    ),
                    title: Text(s.name, style: const TextStyle(fontSize: 15, color: AppPalette.ink)),
                    subtitle: Text(s.line, style: const TextStyle(fontSize: 12, color: AppPalette.subtext)),
                    onTap: () => Navigator.pop(context, s),
                  )),
          ],
        ),
      ),
    );
  }
}

// Category chip

class CategoryChip extends StatelessWidget {
  final ReportCategory category;
  final bool selected;
  final VoidCallback onTap;
  const CategoryChip({super.key, required this.category, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppPalette.teal : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppPalette.teal, width: 1.3),
        ),
        child: Text(
          category.label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppPalette.teal,
          ),
        ),
      ),
    );
  }
}

// Dashed border (used by PhotoPicker)

class DashedBorder extends StatelessWidget {
  final Widget child;
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;

  const DashedBorder({
    super.key,
    required this.child,
    required this.color,
    this.radius = 16,
    this.strokeWidth = 1.4,
    this.dashWidth = 6,
    this.dashSpace = 5,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(
        color: color,
        radius: radius,
        strokeWidth: strokeWidth,
        dashWidth: dashWidth,
        dashSpace: dashSpace,
      ),
      child: child,
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;

  _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashSpace,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(metric.extractPath(distance, next.clamp(0, metric.length)), paint);
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) => false;
}

// Photo picker

class PhotoPicker extends StatelessWidget {
  final File? photo;
  final VoidCallback onTap;
  final VoidCallback onClear;
  const PhotoPicker({super.key, required this.photo, required this.onTap, required this.onClear});

  @override
  Widget build(BuildContext context) {
    if (photo != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(photo!, height: 160, width: double.infinity, fit: BoxFit.cover),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: InkWell(
              onTap: onClear,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: DashedBorder(
        color: AppPalette.teal,
        radius: 16,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22),
          alignment: Alignment.center,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt_outlined, size: 18, color: AppPalette.teal),
              SizedBox(width: 8),
              Text('Add a photo',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppPalette.teal)),
            ],
          ),
        ),
      ),
    );
  }
}

// Submit button

class SubmitButton extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;
  const SubmitButton({super.key, required this.enabled, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: enabled ? onTap : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? AppPalette.teal : AppPalette.tealSoft,
          borderRadius: BorderRadius.circular(26),
        ),
        child: loading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send_rounded,
                      size: 17, color: enabled ? Colors.white : AppPalette.teal.withOpacity(0.45)),
                  const SizedBox(width: 8),
                  Text(
                    'Submit report',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: enabled ? Colors.white : AppPalette.teal.withOpacity(0.45),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// Status badge + Report card

class StatusBadge extends StatelessWidget {
  final FaultStatus status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final open = status == FaultStatus.open;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: open ? AppPalette.redSoft : AppPalette.greenSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        open ? 'Broken' : 'Working',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: open ? AppPalette.red : AppPalette.green,
        ),
      ),
    );
  }
}

class ReportCard extends StatelessWidget {
  final FaultReport report;
  const ReportCard({super.key, required this.report});

  String get _title => ReportCategory.fromIssueType(report.issueType).label;

  String get _relativeTime {
    final diff = DateTime.now().difference(report.createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }

  @override
  Widget build(BuildContext context) {
    final open = report.status == FaultStatus.open;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            open ? Icons.error : Icons.check_circle,
            color: open ? AppPalette.red : AppPalette.green,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _title,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppPalette.ink),
                      ),
                    ),
                    StatusBadge(status: report.status),
                  ],
                ),
                if (report.description != null) ...[
                  const SizedBox(height: 3),
                  Text(report.description!, style: const TextStyle(fontSize: 13, color: AppPalette.subtext)),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 13, color: AppPalette.subtext),
                    const SizedBox(width: 4),
                    Text(_relativeTime, style: const TextStyle(fontSize: 12, color: AppPalette.subtext)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
