import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

/// Service pour gérer l'authentification admin
class AuthService {
  static const String _tokenKey = 'admin_token';
  
  /// Stocke le token admin (en mémoire et en persistance)
  static Future<void> setToken(String token) async {
    // Stocker dans les headers Dio (pour les requêtes immédiates)
    ApiClient.dio.options.headers['x-admin-token'] = token;
    
    // Stocker dans SharedPreferences (pour la persistance)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }
  
  /// Récupère le token admin (depuis la mémoire ou la persistance)
  static Future<String?> getToken() async {
    // D'abord vérifier dans les headers Dio
    final tokenFromHeaders = ApiClient.dio.options.headers['x-admin-token'] as String?;
    if (tokenFromHeaders != null && tokenFromHeaders.isNotEmpty) {
      return tokenFromHeaders;
    }
    
    // Sinon, charger depuis SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    
    // Si trouvé, le remettre dans les headers
    if (token != null && token.isNotEmpty) {
      ApiClient.dio.options.headers['x-admin-token'] = token;
    }
    
    return token;
  }
  
  /// Vérifie si l'utilisateur est authentifié
  static Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
  
  /// Déconnecte l'utilisateur (supprime le token)
  static Future<void> logout() async {
    // Supprimer des headers
    ApiClient.dio.options.headers.remove('x-admin-token');
    
    // Supprimer de SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
  
  /// Initialise le token au démarrage de l'app
  static Future<void> initialize() async {
    await getToken(); // Charge le token depuis SharedPreferences si disponible
  }
}

