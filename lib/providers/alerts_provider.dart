import 'package:flutter/foundation.dart';
import '../core/malaysia_time.dart';
import '../services/alerts_repository.dart';
import '../services/delay_alert_service.dart';
import '../services/leave_by_repository.dart';
import '../services/notification_service.dart';
import '../services/weekly_summary_repository.dart';
import '../models/saved_station.dart';
import '../models/mute_settings.dart';
import '../models/ride_log.dart';

enum LoadStatus { initial, loading, loaded, error }

class AlertsProvider extends ChangeNotifier {
  final AlertsRepository _repository;
  final WeeklySummaryRepository _ridesRepository = WeeklySummaryRepository();
  final DelayAlertService _delayAlertService;
  final LeaveByRepository _leaveByRepository = LeaveByRepository();
  final String userId;

  AlertsProvider({
    required AlertsRepository repository,
    required this.userId,
  })  : _repository = repository,
        _delayAlertService = DelayAlertService.instance {
    _delayAlertService.lastCheckedAt.addListener(notifyListeners);
  }

  LoadStatus status = LoadStatus.initial;
  String? errorMessage;

  List<SavedStation> savedStations = [];
  MuteSettings? muteSettings;
  List<RideLog> recentRides = [];

  bool get isMutedNow => muteSettings?.isMutedNow ?? false;
  DateTime? get lastAlertCheckedAt => _delayAlertService.lastCheckedAt.value;

  @override
  void dispose() {
    _delayAlertService.lastCheckedAt.removeListener(notifyListeners);
    super.dispose();
  }

  Future<void> loadAll() async {
    status = LoadStatus.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getSavedStations(userId),
        _repository.getMuteSettings(userId),
        _ridesRepository.getRecentRides(userId),
      ]);
      savedStations = results[0] as List<SavedStation>;
      muteSettings = results[1] as MuteSettings?;
      recentRides = results[2] as List<RideLog>;
      status = LoadStatus.loaded;
    } catch (e) {
      errorMessage = e.toString();
      status = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> muteToday() async {
    final today = MalaysiaTime.now();
    await _setMute(DateTime(today.year, today.month, today.day));
  }

  Future<void> muteUntilDate(DateTime date) async {
    await _setMute(date);
  }

  Future<void> unmute() async {
    await _setMute(null);
  }

  Future<void> _setMute(DateTime? mutedUntil) async {
    try {
      muteSettings = await _repository.setMute(userId, mutedUntil);
      if (mutedUntil != null) {
        final routes = await _leaveByRepository.getSavedRoutes(userId);
        for (final route in routes) {
          await NotificationService.cancelReminder(route.id.hashCode);
        }
      }
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> removeAlertRule(String savedStationId) async {
    try {
      await _repository.deleteSavedStation(savedStationId);
      savedStations.removeWhere((s) => s.id == savedStationId);
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> toggleStationEnabled(String savedStationId, bool enabled) async {
    final index = savedStations.indexWhere((s) => s.id == savedStationId);
    if (index < 0) return;

    final previous = savedStations[index];
    savedStations[index] = previous.copyWith(enabled: enabled);
    notifyListeners();

    try {
      await _repository.setEnabled(savedStationId, enabled);
    } catch (e) {
      savedStations[index] = previous;
      errorMessage = e.toString();
      notifyListeners();
    }
  }
}
