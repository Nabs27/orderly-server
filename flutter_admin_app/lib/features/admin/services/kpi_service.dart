import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../../core/auth_service.dart';
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

    // 🆕 DEBUG: Log des paramètres envoyés
    print('[KPI Android Service] Paramètres envoyés:');
    print('  - dateFrom: ${start.toIso8601String()}');
    print('  - dateTo: ${end.toIso8601String()}');
    print('  - period: ${period ?? 'ALL'}');
    print('  - server: ${server ?? 'null'}');

    try {
      // Le token sera ajouté automatiquement par l'interceptor
      final response = await ApiClient.dio.get(
        '/api/admin/report-x',
        queryParameters: queryParams,
      );

      // 🆕 CORRECTION WEB : Convertir response.data avec Map.from() pour Flutter Web
      dynamic responseDataRaw = response.data;
      Map<String, dynamic> reportData;
      
      if (responseDataRaw is Map) {
        reportData = Map<String, dynamic>.from(responseDataRaw);
      } else {
        throw Exception('Format de réponse invalide: response.data n\'est pas un Map');
      }
      
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

