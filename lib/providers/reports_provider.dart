import 'package:flutter/foundation.dart';
import '../services/reports_repository.dart';
import '../models/fault_report.dart';

enum LoadStatus { initial, loading, loaded, error }

class ReportsProvider extends ChangeNotifier {
  final ReportsRepository _repository;
  final String userId;

  ReportsProvider({
    required ReportsRepository repository,
    required this.userId,
  }) : _repository = repository;

  LoadStatus status = LoadStatus.initial;
  String? errorMessage;
  List<FaultReport> myReports = [];

  Future<void> loadMyReports() async {
    status = LoadStatus.loading;
    errorMessage = null;
    notifyListeners();

    try {
      myReports = await _repository.getMyReports(userId);
      status = LoadStatus.loaded;
    } catch (e) {
      errorMessage = e.toString();
      status = LoadStatus.error;
    }
    notifyListeners();
  }
}
