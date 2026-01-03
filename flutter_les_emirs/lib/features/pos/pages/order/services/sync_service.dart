import 'package:shared_preferences/shared_preferences.dart';

/// Service pour la synchronisation
class SyncService {
  /// Forcer la synchronisation des tables (pour fermeture après paiement complet)
  static Future<void> forceTableSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pos_force_table_sync', true);
      print('[POS] Synchronisation forcée des tables demandée');
    } catch (e) {
      print('[POS] Erreur lors de la demande de synchronisation: $e');
    }
  }
}

