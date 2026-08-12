import 'package:flutter/foundation.dart';
import '../repositories/alerts_repository.dart';
import '../../../core/models/saved_station.dart';
import '../../../core/models/mute_settings.dart';

enum LoadStatus { initial, loading, loaded, error }

class AlertsProvider extends ChangeNotifier {
  final AlertsRepository _repository;
  final String userId;

  AlertsProvider({required AlertsRepository repository, required this.userId})
      : _repository = repository;

  LoadStatus status = LoadStatus.initial;
  String? errorMessage;

  List<SavedStation> savedStations = [];
  MuteSettings? muteSettings;

  bool get isMutedNow => muteSettings?.isMutedNow ?? false;

  Future<void> loadAll() async {
    status = LoadStatus.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getSavedStations(userId),
        _repository.getMuteSettings(userId),
      ]);
      savedStations = results[0] as List<SavedStation>;
      muteSettings = results[1] as MuteSettings?;
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
}