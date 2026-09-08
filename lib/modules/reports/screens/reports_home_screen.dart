import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/fault_report.dart';
import '../../../providers/reports_provider.dart';
import '../../../services/reports_repository.dart';
import '../../../services/auth_service.dart';
import '../widgets/report_card.dart';
import 'report_detail_screen.dart';
import 'report_issue_screen.dart';






class ReportsHomeScreen extends StatelessWidget {
  const ReportsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = AuthService.currentUserId;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('Not signed in')),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => ReportsProvider(
        repository: ReportsRepository(),
        userId: userId,
      )..loadMyReports(),
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Reports')),
          body: const _ReportsHomeBody(),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('Report an issue'),
            onPressed: () async {
              final submitted = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const ReportIssueScreen()),
              );




              if (submitted == true && context.mounted) {
                context.read<ReportsProvider>().loadMyReports();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Report submitted. Tap it in My reports to view details.'),
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }
}

class _ReportsHomeBody extends StatelessWidget {
  const _ReportsHomeBody();



  Future<void> _confirmResolve(
    BuildContext context,
    ReportsProvider provider,
    FaultReport report,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mark as resolved?'),
        content: const Text(
          'Other riders will stop seeing this as an active issue at the '
          'station. Only do this if the problem is actually fixed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Mark resolved'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final messenger = ScaffoldMessenger.of(context);
    final succeeded = await provider.resolveReport(report.id);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          succeeded
              ? 'Report marked resolved.'
              : 'Could not update that report. Try again.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportsProvider>(
      builder: (context, provider, _) {
        if (provider.status == LoadStatus.loading || provider.status == LoadStatus.initial) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.status == LoadStatus.error) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Failed to load: ${provider.errorMessage}'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: provider.loadMyReports,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (provider.myReports.isEmpty) {
          return RefreshIndicator(
            onRefresh: provider.loadMyReports,
            child: ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    "You haven't reported anything yet. Tap \"Report an "
                    "issue\" to flag a broken lift, escalator, overcrowding, "
                    "or other station issue for other riders.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: provider.loadMyReports,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: provider.myReports.length,
            itemBuilder: (context, index) {
              final report = provider.myReports[index];
              return ReportCard(
                report: report,
                onResolve: () => _confirmResolve(context, provider, report),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ReportDetailScreen(report: report),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
