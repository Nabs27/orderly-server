import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../../core/auth_service.dart';
import '../models/credit_report_model.dart';

class CreditReportService {

  static Future<CreditReport> loadReport({
    DateTime? dateFrom,
    DateTime? dateTo,
    String period = 'ALL',
    String? server,
  }) async {
    final now = DateTime.now();
    final from = dateFrom ?? DateTime(now.year, now.month, now.day);
    final to = dateTo ?? from.add(const Duration(days: 1));

    final queryParams = <String, dynamic>{
      'dateFrom': from.toIso8601String(),
      'dateTo': to.toIso8601String(),
      'period': period,
    };

    if (server != null && server.trim().isNotEmpty) {
      queryParams['server'] = server.trim();
    }

      // Le token sera ajouté automatiquement par l'interceptor
      final response = await ApiClient.dio.get(
      '/api/admin/credit-report',
      queryParameters: queryParams,
    );

    return CreditReport.fromJson(
      (response.data as Map).cast<String, dynamic>(),
    );
  }

  static Future<String> buildTicketUrl({
    DateTime? dateFrom,
    DateTime? dateTo,
    String period = 'ALL',
    String? server,
  }) async {
    // Récupérer le token depuis AuthService
    final token = await AuthService.getToken();
    if (token == null) {
      throw Exception('Non authentifié. Veuillez vous reconnecter.');
    }
    
    final now = DateTime.now();
    final from = dateFrom ?? DateTime(now.year, now.month, now.day);
    final to = dateTo ?? from.add(const Duration(days: 1));

    final queryParams = <String, String>{
      'dateFrom': from.toIso8601String(),
      'dateTo': to.toIso8601String(),
      'period': period,
      'x-admin-token': token,
    };

    if (server != null && server.trim().isNotEmpty) {
      queryParams['server'] = server.trim();
    }

    final baseUrl = ApiClient.dio.options.baseUrl;
    final queryString = queryParams.entries
        .map(
          (e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');

    return '$baseUrl/api/admin/credit-report-ticket?$queryString';
  }
}

