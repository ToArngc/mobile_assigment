import '../models/mute_settings.dart';
import 'alerts_repository.dart';

/// One place to ask "is this user muted right now?".
///
/// Design doc §9: Quick Mute suppresses ANY local reminder, not just
/// delay alerts. The check previously lived inline in DelayAlertService,
/// which meant the Leave-By path simply never had one and muted users
/// still got pinged. Both paths now call this.
///
/// Errors are not swallowed here — a caller that cannot reach
/// mute_settings should decide for itself whether to proceed, rather than
/// having a network failure silently read as "not muted".
class MuteService {
  static final AlertsRepository _repository = AlertsRepository();

  static Future<bool> isMutedNow(String userId) async {
    final MuteSettings? settings = await _repository.getMuteSettings(userId);
    return settings?.isMutedNow ?? false;
  }
}
