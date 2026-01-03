import 'package:flutter/material.dart';
import '../services/history_service.dart';

/// Controller pour gérer l'état de l'historique
class HistoryController {
  bool isLoading = false;
  List<Map<String, dynamic>> orders = [];
  Map<String, Map<String, dynamic>> processedTables = {}; // 🆕 Tables avec données pré-traitées

  /// Charger l'historique pour un serveur
  Future<void> loadHistory(String serverName) async {
    isLoading = true;
    try {
      final data = await HistoryService.getArchivedOrders(serverName);
      orders = List<Map<String, dynamic>>.from(data['orders'] ?? []);
      processedTables = Map<String, Map<String, dynamic>>.from(data['processedTables'] ?? {});
    } catch (e) {
      print('[HISTORY] Erreur chargement historique: $e');
      rethrow;
    } finally {
      isLoading = false;
    }
  }

  /// Réinitialiser l'état
  void reset() {
    orders.clear();
    processedTables.clear();
    isLoading = false;
  }
  
  /// Obtenir les sessions d'une table (compatibilité)
  Map<String, List<Map<String, dynamic>>> get groupedTables {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final entry in processedTables.entries) {
      final tableNumber = entry.key;
      final tableData = entry.value;
      final sessions = tableData['sessions'] as List? ?? [];
      grouped[tableNumber] = List<Map<String, dynamic>>.from(sessions);
    }
    return grouped;
  }
}

