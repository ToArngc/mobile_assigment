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
  final Map<String, LeaveByResult?> results = {};

  Future<void> loadAll() async {
    status = LoadStatus.loading;
    errorMessage = null;
    notifyListeners();

    try {
      routes = await _repository.getSavedRoutes(userId);
      results.clear();



      final muted = await MuteService.isMutedNow(userId);

      for (final route in routes) {
        try {
          final result = await _repository.computeLeaveByTime(route);
          results[route.id] = result;

          if (muted) {



            await NotificationService.cancelReminder(route.id.hashCode);
            continue;
          }




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