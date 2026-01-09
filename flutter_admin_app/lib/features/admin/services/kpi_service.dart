import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../models/kpi_model.dart';

/// Service pour récupérer et gérer les KPI du dashboard admin
class KpiService {
  /// Charge les KPI pour une période donnée
  /// 
  /// [dateFrom] et [dateTo] définissent la période (optionnel, par défaut aujourd'hui)
  /// [period] peut être 'ALL', 'MIDI', ou 'SOIR' (optionnel, par défaut 'ALL')
  /// [server] filtre par serveur (optionnel)
  static Future<KpiModel> loadKpis({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? period,
    String? server,
  }) async {
    // Par défaut, charger les données du jour
    final now = DateTime.now();
    final start = dateFrom ?? DateTime(now.year, now.month, now.day);
    // 🆕 Pour dateTo, inclure toute la journée (jusqu'à 23:59:59.999)
    final end = dateTo ?? DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    final queryParams = <String, dynamic>{
      'dateFrom': start.toIso8601String(),
      'dateTo': end.toIso8601String(),
      'period': period ?? 'ALL',
    };

    if (server != null && server.isNotEmpty) {
      queryParams['server'] = server;
    }

    try {
      final response = await ApiClient.dio.get(
        '/api/admin/report-x',
        queryParameters: queryParams,
        options: Options(
          headers: {'x-admin-token': 'admin123'},
        ),
      );

      // 🆕 Vérifier que response.data est bien un Map
      if (response.data is! Map) {
        print('[KPI Service] ⚠️ response.data n\'est pas un Map: ${response.data.runtimeType}');
        print('[KPI Service] response.data: ${response.data}');
        throw Exception('Format de réponse invalide: response.data n\'est pas un Map');
      }
      
      final reportData = response.data as Map<String, dynamic>;
      
      // 🆕 Log pour debug
      print('[KPI Service] ✅ Données reçues, clés: ${reportData.keys.toList()}');
      print('[KPI Service] itemsByCategory type: ${reportData['itemsByCategory']?.runtimeType}');
      print('[KPI Service] paymentsByMode type: ${reportData['paymentsByMode']?.runtimeType}');
      
      return KpiModel.fromReportXData(reportData);
    } catch (e, stackTrace) {
      print('[KPI Service] ❌ Erreur détaillée: $e');
      print('[KPI Service] Stack trace: $stackTrace');
      throw Exception('Erreur lors du chargement des KPI: $e');
    }
  }

  /// Charge les KPI du jour en cours
  static Future<KpiModel> loadTodayKpis({String? server}) {
    return loadKpis(period: 'ALL', server: server);
  }

  /// Charge les KPI du midi (avant 15h)
  static Future<KpiModel> loadMidiKpis({String? server}) {
    return loadKpis(period: 'MIDI', server: server);
  }

  /// Charge les KPI du soir (à partir de 15h)
  static Future<KpiModel> loadSoirKpis({String? server}) {
    return loadKpis(period: 'SOIR', server: server);
  }
}

