import 'package:flutter/foundation.dart';
import '../repositories/alerts_repository.dart';
import '../repositories/weekly_summary_repository.dart';
import '../../../core/models/saved_station.dart';
import '../../../core/models/mute_settings.dart';
import '../../../core/models/ride_log.dart';

enum LoadStatus { initial, loading, loaded, error }

class AlertsProvider extends ChangeNotifier {
  final AlertsRepository _repository;
  final WeeklySummaryRepository _ridesRepository;
  final String userId;

  AlertsProvider({
    required AlertsRepository repository,
    required this.userId,
    WeeklySummaryRepository? ridesRepository,
  })  : _repository = repository,
        _ridesRepository = ridesRepository ?? WeeklySummaryRepository();

  LoadStatus status = LoadStatus.initial;
  String? errorMessage;

  List<SavedStation> savedStations = [];
  MuteSettings? muteSettings;
  List<RideLog> recentRides = [];

  bool get isMutedNow => muteSettings?.isMutedNow ?? false;

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

  // ---- Quick Mute ----

  /// "No Commute Today" — mutes until end of today.
  Future<void> muteToday() async {
    final endOfToday = DateTime.now();
    await _setMute(DateTime(endOfToday.year, endOfToday.month, endOfToday.day));
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
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  // ---- Alert Rules ----

  Future<void> saveAlertRule(SavedStation station) async {
    try {
      final saved = await _repository.upsertSavedStation(station);
      final index = savedStations.indexWhere((s) => s.id == saved.id);
      if (index >= 0) {
        savedStations[index] = saved;
      } else {
        savedStations.add(saved);
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

  /// Optimistic update — flips the switch immediately, reverts if the
  /// write fails, rather than making the user wait on every tap.
  Future<void> toggleStationEnabled(String savedStationId, bool enabled) async {
    final index = savedStations.indexWhere((s) => s.id == savedStationId);
    if (index < 0) return;

    final previous = savedStations[index];
    savedStations[index] = previous.copyWith(enabled: enabled);
    notifyListeners();

    try {
      await _repository.setEnabled(savedStationId, enabled);
    } catch (e) {
      savedStations[index] = previous; // revert
      errorMessage = e.toString();
      notifyListeners();
    }
  }
}