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

  /// Marks one of the rider's own reports resolved (fix task 11,
  /// option A). resolve-fault-report re-checks ownership server-side, so
  /// this cannot close someone else's report even if an id were forged.
  ///
  /// The row is updated in place rather than refetching the whole list,
  /// so the card flips to Resolved immediately.
  Future<bool> resolveReport(String reportId) async {
    try {
      await _repository.markResolved(reportId);
      final index = myReports.indexWhere((report) => report.id == reportId);
      if (index != -1) {
        myReports[index] = myReports[index].copyWithResolved();
      }
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

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
