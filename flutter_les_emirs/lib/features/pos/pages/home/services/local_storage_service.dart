import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static Future<void> clearPosCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    print('[STORAGE] 🧹 Nettoyage complet du cache POS...');
    
    for (final key in keys) {
      // 🆕 Nettoyer tout ce qui est lié aux données (tables, commandes, sessions)
      // On préserve uniquement la configuration API et les réglages de base
      bool isConfig = key == 'api_local_url' || 
                      key == 'api_cloud_url' || 
                      key == 'api_use_cloud' || 
                      key == 'pos_user_name' || 
                      key == 'pos_user_role';
                      
      if (!isConfig) {
        if (key.startsWith('pos_') || 
            key.startsWith('table_') || 
            key.contains('order') || 
            key.contains('session')) {
          print('[STORAGE]   - Suppression de la clé: $key');
          await prefs.remove(key);
        }
      }
    }
    print('[STORAGE] ✅ Cache POS vidé');
  }
}
