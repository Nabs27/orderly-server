import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  ApiClient._();

  // 🆕 URL par défaut locale pour développement
  // Sera remplacée par main.dart au démarrage après chargement du .env
  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: 'http://localhost:3000', // 🆕 Par défaut local, sera remplacé par main.dart
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Content-Type': 'application/json',
      },
    ),
  );
  
  // 🆕 Interceptor pour ajouter automatiquement le token admin à toutes les requêtes /api/admin
  static void setupInterceptors() {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Ajouter le token admin pour toutes les requêtes admin
        if (options.path.startsWith('/api/admin')) {
          // Vérifier si le token est déjà dans les headers (depuis AuthService.setToken)
          final existingToken = options.headers['x-admin-token'] as String?;
          if (existingToken == null || existingToken.isEmpty) {
            // Charger depuis SharedPreferences si pas dans les headers
            try {
              final prefs = await SharedPreferences.getInstance();
              final token = prefs.getString('admin_token');
              if (token != null && token.isNotEmpty) {
                options.headers['x-admin-token'] = token;
                // Mettre à jour aussi les headers par défaut
                dio.options.headers['x-admin-token'] = token;
              }
            } catch (e) {
              print('[API] Erreur chargement token: $e');
            }
          }
        }
        handler.next(options);
      },
      onError: (error, handler) {
        // Si erreur 401, le token est peut-être invalide
        if (error.response?.statusCode == 401) {
          print('[API] Erreur 401 - Token invalide ou expiré');
        }
        handler.next(error);
      },
    ));
  }
}


