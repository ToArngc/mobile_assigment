import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/alerts_provider.dart';


class QuickMuteCard extends StatelessWidget {
  const QuickMuteCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AlertsProvider>(
      builder: (context, provider, _) {
        final isMuted = provider.isMutedNow;
        final mutedUntil = provider.muteSettings?.mutedUntil;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                secondary: Icon(
                  isMuted ? Icons.notifications_off : Icons.notifications_active,
                ),
                title: Text(isMuted ? 'Alerts muted' : 'Alerts active'),
                subtitle: Text(_subtitleText(isMuted, mutedUntil)),
                value: isMuted,
                onChanged: (value) async {
                  if (value) {
                    await provider.muteToday();
                  } else {
                    await provider.unmute();
                  }
                  if (provider.errorMessage != null && context.mounted) {
                    _showError(context, provider.errorMessage!);
                  }
                },
              ),
              const Divider(height: 1),
              TextButton.icon(
                icon: const Icon(Icons.event_busy, size: 18),
                label: const Text('Mute until a date…'),
                onPressed: () => _pickMuteUntilDate(context, provider),
              ),
            ],
          ),
        );
      },
    );
  }

  String _subtitleText(bool isMuted, DateTime? mutedUntil) {
    if (!isMuted) return 'You\'ll get delay and departure alerts as usual';
    if (mutedUntil == null) return 'Muted';
    final today = DateTime.now();
    final isToday = mutedUntil.year == today.year &&
        mutedUntil.month == today.month &&
        mutedUntil.day == today.day;
    if (isToday) return 'Muted for today only';
    return 'Muted until ${_formatDate(mutedUntil)}';
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  Future<void> _pickMuteUntilDate(
      BuildContext context,
      AlertsProvider provider,
      ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      helpText: 'Mute alerts until',
    );

    if (picked == null || !context.mounted) return;

    await provider.muteUntilDate(picked);
    if (provider.errorMessage != null && context.mounted) {
      _showError(context, provider.errorMessage!);
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}