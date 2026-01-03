import '../../../../admin/models/kpi_model.dart';
import 'server_sales_report_service.dart';

/// Controller pour gérer l'état du rapport de ventes serveur
class ServerSalesReportController {
  bool isLoading = false;
  KpiModel? report;
  String? error;

  /// Charger le rapport du jour pour un serveur
  Future<void> loadTodayReport(String serverName) async {
    isLoading = true;
    error = null;
    try {
      report = await ServerSalesReportService.loadTodayReport(serverName);
    } catch (e) {
      error = e.toString();
      print('[SERVER_REPORT] Erreur chargement rapport: $e');
      rethrow;
    } finally {
      isLoading = false;
    }
  }

  /// Réinitialiser l'état
  void reset() {
    report = null;
    error = null;
    isLoading = false;
  }
}

