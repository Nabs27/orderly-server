// ✅ Service pour confirmer les commandes client par le serveur
// Respecte la structure modulaire du POS

import 'package:dio/dio.dart';
import '../../../../../../core/api_client.dart';

class ClientOrderConfirmationService {
  /// Confirmer une commande client par le serveur
  /// 
  /// [orderId] : ID de la commande à confirmer (int pour ID officiel, String pour tempId)
  /// [serverName] : Nom du serveur qui confirme (optionnel, sera utilisé depuis la commande si non fourni)
  /// 
  /// Retourne la commande mise à jour
  static Future<Map<String, dynamic>> confirmClientOrder({
    required dynamic orderId, // 🆕 Accepte int (ID officiel) ou String (tempId pour commandes client)
    String? serverName,
  }) async {
    try {
      final response = await ApiClient.dio.patch(
        '/orders/$orderId/confirm-by-server',
        data: serverName != null ? {'server': serverName} : null,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Commande introuvable');
      } else if (e.response?.statusCode == 400) {
        final error = e.response?.data is Map && e.response?.data['error'] is String
            ? e.response?.data['error']
            : 'Impossible de confirmer cette commande';
        throw Exception(error);
      }
      throw Exception('Erreur lors de la confirmation: ${e.message}');
    } catch (e) {
      throw Exception('Erreur lors de la confirmation: $e');
    }
  }

  /// Vérifier si une commande est une commande client en attente de confirmation
  static bool isPendingClientOrder(Map<String, dynamic> order) {
    final source = order['source'] as String?;
    final status = order['status'] as String?;
    final serverConfirmed = order['serverConfirmed'] as bool?;
    
    return source == 'client' && 
           status == 'pending_server_confirmation' && 
           (serverConfirmed == false || serverConfirmed == null);
  }

  /// Vérifier si le serveur actuel peut confirmer cette commande
  static bool canCurrentServerConfirm(Map<String, dynamic> order, String currentServer) {
    if (!isPendingClientOrder(order)) return false;
    final assignedServer = order['server'] as String?;
    return assignedServer == currentServer;
  }

  /// 🆕 Décliner une commande client par le serveur
  /// 
  /// [orderId] : ID de la commande à décliner (int pour ID officiel, String pour tempId)
  /// [reason] : Raison optionnelle du refus
  /// [serverName] : Nom du serveur qui décline (optionnel)
  /// 
  /// Retourne la commande déclinée
  static Future<Map<String, dynamic>> declineClientOrder({
    required dynamic orderId, // 🆕 Accepte int (ID officiel) ou String (tempId pour commandes client)
    String? reason,
    String? serverName,
  }) async {
    try {
      final response = await ApiClient.dio.patch(
        '/orders/$orderId/decline-by-server',
        data: {
          if (reason != null) 'reason': reason,
          if (serverName != null) 'server': serverName,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Commande introuvable');
      } else if (e.response?.statusCode == 400) {
        final error = e.response?.data is Map && e.response?.data['error'] is String
            ? e.response?.data['error']
            : 'Impossible de décliner cette commande';
        throw Exception(error);
      }
      throw Exception('Erreur lors de la déclinaison: ${e.message}');
    } catch (e) {
      throw Exception('Erreur lors de la déclinaison: $e');
    }
  }
}

