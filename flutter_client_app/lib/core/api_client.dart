import 'package:dio/dio.dart';

class ApiClient {
  ApiClient._();

  // 🆕 URL par défaut locale pour développement
  // Sera remplacée par ApiPrefsService au démarrage
  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: 'http://localhost:3000', // 🆕 Par défaut local au lieu de cloud
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Content-Type': 'application/json',
      },
    ),
  );
}



