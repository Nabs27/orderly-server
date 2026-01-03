import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter/foundation.dart';

class HomeSocketService {
  io.Socket? _socket;

  io.Socket connect(String baseUrl) {
    final uri = baseUrl.replaceAll(RegExp(r"/+$$"), '');
    print('[POS HOME] 🔌 Création socket Socket.IO vers: $uri');
    // Note: socket_io_client se connecte automatiquement par défaut lors de la création
    final s = io.io(uri, io.OptionBuilder()
        .setTransports(['websocket'])
        .setExtraHeaders({'Origin': uri})
        .build());
    _socket = s;
    print('[POS HOME] ✅ Socket créé (connexion automatique par défaut)');
    return s;
  }

  void bindDefaultHandlers({
    required Future<void> Function() onSync,
    required VoidCallback onUiUpdate,
  }) {
    final s = _socket;
    if (s == null) {
      print('[POS HOME] ⚠️ Socket est null, impossible d\'attacher les handlers');
      return;
    }

    // ⚠️ IMPORTANT : Retirer les listeners existants avant d'en ajouter de nouveaux
    // pour éviter les listeners dupliqués qui causent des événements multiples
    try {
      s.off('connect');
      s.off('disconnect');
      s.off('connect_error');
      s.off('order:new');
      s.off('order:updated');
      s.off('order:archived');
      s.off('table:created');
      s.off('table:cleared');
      s.off('server:transferred');
      s.off('table:transferred');
      s.off('system:reset');
    } catch (e) {
      print('[POS HOME] Erreur lors du nettoyage des listeners avant bind: $e');
    }

    void _resync(_) async {
      print('[POS HOME] 📢 Événement Socket.IO reçu, synchronisation en cours...');
      await onSync();
      // Différer l'appel pour éviter les problèmes de timing
      Future.microtask(() {
        print('[POS HOME] 🔄 Mise à jour UI après synchronisation');
        onUiUpdate();
      });
    }

    // 🆕 CRITIQUE : Attacher TOUS les listeners AVANT de connecter
    // pour éviter de manquer des événements émis pendant la connexion
    
    s.on('connect', (_) {
      print('[POS HOME] ✅ Socket.IO connecté (id: ${s.id})');
      // Différer l'appel pour éviter les problèmes de timing
      Future.microtask(() => onUiUpdate());
    });
    
    s.on('disconnect', (_) {
      print('[POS HOME] ⚠️ Socket.IO déconnecté');
      // ⚠️ IMPORTANT : Différer l'appel et permettre au callback de vérifier mounted
      // Ne pas appeler onUiUpdate() si le widget est détruit
      Future.microtask(() {
        // Le callback onUiUpdate() doit vérifier mounted lui-même
        try {
          onUiUpdate();
        } catch (e) {
          // Ignorer silencieusement si le widget est détruit
          // (onUiUpdate vérifie déjà mounted)
        }
      });
    });
    
    s.on('connect_error', (error) {
      print('[POS HOME] ❌ Erreur de connexion Socket.IO: $error');
      Future.microtask(() => onUiUpdate());
    });

    // 🆕 Attacher les listeners d'événements métier AVANT la connexion
    s.on('order:new', (payload) {
      print('[POS HOME] 📨 Événement order:new reçu avec payload: ${payload != null ? "données présentes" : "null"}');
      _resync(payload);
    });
    s.on('order:updated', _resync);
    s.on('order:archived', _resync);
    s.on('table:created', (_) => Future.microtask(() => onUiUpdate()));
    s.on('table:cleared', _resync);
    s.on('server:transferred', _resync);
    s.on('table:transferred', _resync);
    s.on('system:reset', _resync);
    
    print('[POS HOME] 📡 Tous les listeners Socket.IO attachés');
    
    // 🆕 CRITIQUE : Toujours appeler connect() pour s'assurer que le socket est connecté
    // Même si autoConnect=true, il faut s'assurer que la connexion est établie
    // Vérifier l'état actuel pour le log
    final currentState = 'id=${s.id}, connected=${s.connected}';
    print('[POS HOME] Socket état avant connexion: $currentState');
    
    // Toujours appeler connect() - socket.io gère intelligemment les reconnexions
    print('[POS HOME] 🔌 Appel connect() pour établir/maintenir la connexion...');
    s.connect();
    
    // Vérifier l'état après un court délai (pour le log)
    Future.delayed(const Duration(milliseconds: 500), () {
      print('[POS HOME] Socket état après connexion: id=${s.id}, connected=${s.connected}');
      if (!s.connected) {
        print('[POS HOME] ⚠️ ATTENTION: Socket non connecté après 500ms !');
      }
    });
  }

  void dispose() {
    if (_socket != null) {
      // Retirer tous les listeners avant de disconnect
      try {
        _socket!.off('connect');
        _socket!.off('disconnect');
        _socket!.off('connect_error');
        _socket!.off('order:new');
        _socket!.off('order:updated');
        _socket!.off('order:archived');
        _socket!.off('table:created');
        _socket!.off('table:cleared');
        _socket!.off('server:transferred');
        _socket!.off('table:transferred');
        _socket!.off('system:reset');
      } catch (e) {
        print('[POS HOME] Erreur lors du retrait des listeners socket: $e');
      }
      
      try {
        _socket!.disconnect();
      } catch (e) {
        print('[POS HOME] Erreur lors de la déconnexion socket: $e');
      }
      
      try {
        _socket!.dispose();
      } catch (e) {
        print('[POS HOME] Erreur lors du dispose socket: $e');
      }
      
      _socket = null;
    }
  }
}


