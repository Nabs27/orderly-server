import 'package:dio/dio.dart';
import '../../../core/api_client.dart';

class ServerPermissionsService {
  static Future<List<Map<String, dynamic>>> loadServerProfiles() async {
    try {
      final response = await ApiClient.dio.get('/api/server-profiles');
      return (response.data as List)
          .cast<Map<String, dynamic>>()
          .map((profile) => {
                'id': profile['id'],
                'name': profile['name'],
                'role': profile['role'] ?? 'Serveur',
                'permissions': Map<String, dynamic>.from(profile['permissions'] ?? {}),
              })
          .toList();
    } on DioException catch (e) {
      print('[POS] Erreur chargement profils serveurs: ${e.message}');
      rethrow;
    }
  }

  static Future<Map<String, bool>> loadPermissionsFor(String serverName) async {
    final normalizedName = serverName.toUpperCase();
    try {
      final response = await ApiClient.dio.get('/api/server-permissions/$normalizedName');
      final perms = Map<String, dynamic>.from(response.data['permissions'] ?? {});
      return perms.map((key, value) => MapEntry(key, value == true));
    } on DioException catch (e) {
      print('[POS] Erreur chargement permissions pour $normalizedName: ${e.message}');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> verifyOverridePin(String pin) async {
    try {
      final response = await ApiClient.dio.post(
        '/api/server-override',
        data: {'pin': pin},
      );
      final data = (response.data as Map<String, dynamic>);
      return {
        'id': data['id'],
        'name': data['name'],
        'role': data['role'],
        'permissions': Map<String, dynamic>.from(data['permissions'] ?? {}),
      };
    } on DioException catch (e) {
      print('[POS] Override PIN refusé: ${e.response?.data ?? e.message}');
      rethrow;
    }
  }
}

