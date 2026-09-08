import 'package:flutter/foundation.dart';
import '../services/leave_by_repository.dart';
import '../services/mute_service.dart';
import '../models/saved_route.dart';
import '../services/notification_service.dart';

enum LoadStatus { initial, loading, loaded, error }

class LeaveByProvider extends ChangeNotifier {
  final LeaveByRepository _repository;
  final String userId;

  LeaveByProvider({
    required LeaveByRepository repository,
    required this.userId,
  }) : _repository = repository;

  LoadStatus status = LoadStatus.initial;
  String? errorMessage;
  List<SavedRoute> routes = [];
  final Map<String, LeaveByResult?> results = {}; // routeId -> result (null = no upcoming departure / no data)

  Future<void> loadAll() async {
    status = LoadStatus.loading;
    errorMessage = null;
    notifyListeners();

    try {
      routes = await _repository.getSavedRoutes(userId);
      results.clear();

      // Quick Mute covers every local reminder, Leave-By included
      // (design doc §9). Checked once per load rather than per route.
      final muted = await MuteService.isMutedNow(userId);

      for (final route in routes) {
        try {
          final result = await _repository.computeLeaveByTime(route);
          results[route.id] = result;

          if (muted) {
            // Cancel as well as skip: a reminder scheduled before the
            // mute was set still lives in the OS alarm queue and would
            // otherwise fire anyway.
            await NotificationService.cancelReminder(route.id.hashCode);
            continue;
          }

          // Re-schedule the reminder every time we recompute — this
          // naturally replaces yesterday's (now-past) notification with
          // today's, since the notification id is stable per route.
          if (result != null && result.hasEnoughData) {
            await NotificationService.scheduleLeaveByReminder(
              id: route.id.hashCode,
              leaveByTime: result.leaveByTime,
              stationLabel: 'your route',
            );
          }
        } catch (_) {
          results[route.id] = null;
        }
      }
      status = LoadStatus.loaded;
    } catch (e) {
      errorMessage = e.toString();
      status = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> removeRoute(String routeId) async {
    try {
      await _repository.deleteSavedRoute(routeId);
      routes.removeWhere((r) => r.id == routeId);
      results.remove(routeId);
      await NotificationService.cancelReminder(routeId.hashCode);
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }
}