import '../../../../admin/services/kpi_service.dart';
import '../../../../admin/models/kpi_model.dart';

/// Service pour récupérer le rapport de ventes d'un serveur
/// Utilise KpiService pour garantir la cohérence avec le dashboard admin
class ServerSalesReportService {
  /// Charge les KPI du jour en cours pour un serveur spécifique
  /// Retourne un KpiModel filtré par serveur
  static Future<KpiModel> loadTodayReport(String serverName) async {
    return await KpiService.loadTodayKpis(server: serverName);
  }

  /// Charge les KPI pour une période spécifique
  static Future<KpiModel> loadReport({
    required String serverName,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? period,
  }) async {
    return await KpiService.loadKpis(
      server: serverName,
      dateFrom: dateFrom,
      dateTo: dateTo,
      period: period,
    );
  }
}

