import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter/material.dart';
import '../../../../../../core/api_client.dart';

/// Service Socket.IO pour les mises à jour de crédit client en temps réel
class CreditSocketService {
  io.Socket? _socket;
  final Map<int, List<VoidCallback>> _clientCallbacks = {};

  bool _listenersSetup = false;

  /// Écouter les mises à jour de crédit pour un client spécifique
  void listenToClientUpdates({
    required int clientId,
    required VoidCallback onBalanceUpdated,
  }) {
    _initializeSocket();
    if (_socket == null) return;

    if (!_clientCallbacks.containsKey(clientId)) {
      _clientCallbacks[clientId] = [];
    }
    _clientCallbacks[clientId]!.add(onBalanceUpdated);

    // ⚠️ IMPORTANT : Ne configurer les listeners qu'une seule fois
    if (!_listenersSetup) {
      _listenersSetup = true;
      
      // Écouter les événements globaux
      _socket!.on('client:transaction-added', (payload) {
        final data = (payload as Map).cast<String, dynamic>();
        final updatedClientId = data['clientId'] as int?;
        if (updatedClientId != null) {
          // Appeler les callbacks pour ce client spécifique
          if (_clientCallbacks.containsKey(updatedClientId)) {
            print('[CREDIT SOCKET] Balance mis à jour pour client $updatedClientId');
            for (final callback in _clientCallbacks[updatedClientId]!) {
              try {
                callback();
              } catch (e) {
                print('[CREDIT SOCKET] Erreur callback: $e');
              }
            }
          }
          // Appeler aussi les callbacks globaux (clientId = 0)
          if (_clientCallbacks.containsKey(0)) {
            print('[CREDIT SOCKET] Mise à jour globale déclenchée');
            for (final callback in _clientCallbacks[0]!) {
              try {
                callback();
              } catch (e) {
                print('[CREDIT SOCKET] Erreur callback global: $e');
              }
            }
          }
        }
      });

      _socket!.on('client:payment-added', (payload) {
        final data = (payload as Map).cast<String, dynamic>();
        final updatedClientId = data['clientId'] as int?;
        if (updatedClientId != null) {
          // Appeler les callbacks pour ce client spécifique
          if (_clientCallbacks.containsKey(updatedClientId)) {
            print('[CREDIT SOCKET] Paiement reçu pour client $updatedClientId');
            for (final callback in _clientCallbacks[updatedClientId]!) {
              try {
                callback();
              } catch (e) {
                print('[CREDIT SOCKET] Erreur callback: $e');
              }
            }
          }
          // Appeler aussi les callbacks globaux (clientId = 0)
          if (_clientCallbacks.containsKey(0)) {
            print('[CREDIT SOCKET] Mise à jour globale déclenchée');
            for (final callback in _clientCallbacks[0]!) {
              try {
                callback();
              } catch (e) {
                print('[CREDIT SOCKET] Erreur callback global: $e');
              }
            }
          }
        }
      });
    }
  }

  /// Arrêter d'écouter les mises à jour pour un client
  void stopListeningToClient(int clientId, VoidCallback callback) {
    _clientCallbacks[clientId]?.remove(callback);
    if (_clientCallbacks[clientId]?.isEmpty ?? false) {
      _clientCallbacks.remove(clientId);
    }
  }

  void _initializeSocket() {
    if (_socket != null && _socket!.connected) return;

    final base = ApiClient.dio.options.baseUrl;
    final uri = base.replaceAll(RegExp(r"/+$"), '');
    _socket = io.io(uri, io.OptionBuilder().setTransports(['websocket']).setExtraHeaders({'Origin': uri}).build());
    
    _socket!.on('connect', (_) {
      print('[CREDIT SOCKET] Connecté');
    });
    
    _socket!.on('disconnect', (_) {
      print('[CREDIT SOCKET] Déconnecté');
    });
  }

  void dispose() {
    if (_socket != null) {
      try {
        _socket!.off('client:transaction-added');
        _socket!.off('client:payment-added');
        _socket!.disconnect();
        _socket!.dispose();
      } catch (e) {
        print('[CREDIT SOCKET] Erreur dispose: $e');
      }
      _socket = null;
    }
    _clientCallbacks.clear();
    _listenersSetup = false;
  }
}

