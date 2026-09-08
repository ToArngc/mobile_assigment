import '../models/mute_settings.dart';
import 'alerts_repository.dart';











class MuteService {
  static final AlertsRepository _repository = AlertsRepository();

  static Future<bool> isMutedNow(String userId) async {
    final MuteSettings? settings = await _repository.getMuteSettings(userId);
    return settings?.isMutedNow ?? false;
  }
}
