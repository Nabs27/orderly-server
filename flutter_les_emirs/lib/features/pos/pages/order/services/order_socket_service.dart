import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter/material.dart';
import '../../../../../../core/api_client.dart';

class OrderSocketService {
  io.Socket? _socket;

  // Configurer les listeners Socket.IO
  void setupSocketListeners({
    required String tableNumber,
    required String tableId,
    required BuildContext context,
    required VoidCallback onOrderUpdated,
    required VoidCallback onOrderArchived,
    required VoidCallback onOrderNew,
    required VoidCallback onTableCleared,
    VoidCallback? onOrderServerConfirmed, // 🆕 Callback pour confirmation serveur
  }) {
    // Créer une connexion Socket.IO
    final base = ApiClient.dio.options.baseUrl;
    final uri = base.replaceAll(RegExp(r"/+$"), '');
    _socket = io.io(uri, io.OptionBuilder().setTransports(['websocket']).setExtraHeaders({'Origin': uri}).build());
    final s = _socket!;
    
    print('[POS] Listeners Socket.IO configurés pour synchronisation temps réel');
    
    // Écouter les événements de mise à jour de commandes
    s.on('order:updated', (payload) {
      print('[POS] Événement order:updated reçu pour table $tableNumber');
      onOrderUpdated();
    });
    
    // Écouter les événements d'archivage de commandes
    s.on('order:archived', (payload) {
      print('[POS] Événement order:archived reçu pour commande ${payload['orderId']}, table ${payload['table']}');
      onOrderArchived();
    });
    
    // Écouter les événements de création de nouvelles commandes
    s.on('order:new', (payload) {
      print('[POS] Événement order:new reçu pour table ${payload['table']}, commande ${payload['id']}');
      onOrderNew();
    });
    
    // 🆕 Écouter les événements de confirmation serveur
    if (onOrderServerConfirmed != null) {
      s.on('order:server-confirmed', (payload) {
        print('[POS] Événement order:server-confirmed reçu pour commande ${payload['id']}');
        onOrderServerConfirmed();
      });
    }
    
    // Écouter les événements de nettoyage de table
    s.on('table:cleared', (payload) {
      final data = (payload as Map).cast<String, dynamic>();
      final clearedTable = data['table']?.toString() ?? '';
      
      if (clearedTable == tableNumber) {
        print('[POS] Table $tableNumber nettoyée, retour au plan de table');
        onTableCleared();
      }
    });
  }

  // Fermer la connexion socket
  void dispose() {
    if (_socket != null) {
      // Retirer tous les listeners avant de disconnect pour éviter les callbacks
      try {
        _socket!.off('order:updated');
        _socket!.off('order:archived');
        _socket!.off('order:new');
        _socket!.off('order:server-confirmed'); // 🆕
        _socket!.off('table:cleared');
      } catch (e) {
        print('[POS] Erreur lors du retrait des listeners socket: $e');
      }
      
      try {
        _socket!.disconnect();
      } catch (e) {
        print('[POS] Erreur lors de la déconnexion socket: $e');
      }
      
      try {
        _socket!.dispose();
      } catch (e) {
        print('[POS] Erreur lors du dispose socket: $e');
      }
      
      _socket = null;
    }
  }
}

