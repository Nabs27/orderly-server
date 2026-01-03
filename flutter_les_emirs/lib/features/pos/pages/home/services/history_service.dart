import 'package:dio/dio.dart';
import '../../../../../core/api_client.dart';

/// Service pour récupérer l'historique des tables archivées d'un serveur
class HistoryService {
  /// Récupère l'historique unifié (archivées + actives avec paiements) pour un serveur avec données pré-traitées
  static Future<Map<String, dynamic>> getArchivedOrders(String server) async {
    try {
      final response = await ApiClient.dio.get(
        '/api/pos/history-unified',
        queryParameters: {'server': server},
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          return Map<String, dynamic>.from(data);
        }
        return {'orders': [], 'processedTables': {}};
      }
      
      return {'orders': [], 'processedTables': {}};
    } catch (e) {
      print('[HISTORY] Erreur récupération historique: $e');
      return {'orders': [], 'processedTables': {}};
    }
  }
  
  /// Groupe les sessions par "service" (période entre ouverture et fermeture/archivage)
  /// Un service = toutes les sessions archivées ensemble (même timestamp d'archivage ou très proches)
  static Map<int, List<Map<String, dynamic>>> groupSessionsByService(
    List<Map<String, dynamic>> sessions,
  ) {
    if (sessions.isEmpty) return {};
    
    // Trier les sessions par date d'archivage (plus ancien en premier)
    final sortedSessions = List<Map<String, dynamic>>.from(sessions)
      ..sort((a, b) {
        final dateA = DateTime.tryParse(a['archivedAt'] ?? a['createdAt'] ?? '') ?? DateTime(1970);
        final dateB = DateTime.tryParse(b['archivedAt'] ?? b['createdAt'] ?? '') ?? DateTime(1970);
        return dateA.compareTo(dateB);
      });
    
    final Map<int, List<Map<String, dynamic>>> services = {};
    int currentServiceIndex = 0; // Commencer à 0 pour que la première session soit dans le service 1
    DateTime? lastArchivedAt;
    
    // Seuil pour considérer qu'un nouveau service commence (30 minutes de gap)
    const serviceGapMinutes = 30;
    
    for (final session in sortedSessions) {
      final archivedAtStr = session['archivedAt'] as String?;
      final archivedAt = archivedAtStr != null ? DateTime.tryParse(archivedAtStr) : null;
      
      // Déterminer si c'est un nouveau service
      bool isNewService = false;
      if (lastArchivedAt == null) {
        // Première session = nouveau service
        isNewService = true;
      } else if (archivedAt != null) {
        // Vérifier le gap entre les archivages
        final gap = archivedAt.difference(lastArchivedAt);
        if (gap.inMinutes > serviceGapMinutes) {
          // Gap trop grand = nouveau service
          isNewService = true;
        }
      }
      
      if (isNewService) {
        currentServiceIndex++;
        services[currentServiceIndex] = [];
      }
      
      services[currentServiceIndex]!.add(session);
      lastArchivedAt = archivedAt ?? DateTime.tryParse(session['createdAt'] ?? '');
    }
    
    return services;
  }
  
  /// Groupe les commandes archivées par numéro de table
  /// Retourne une Map: tableNumber -> liste des sessions (commandes)
  static Map<String, List<Map<String, dynamic>>> groupByTable(
    List<Map<String, dynamic>> orders,
  ) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    
    for (final order in orders) {
      final tableNumber = order['table']?.toString() ?? '?';
      if (!grouped.containsKey(tableNumber)) {
        grouped[tableNumber] = [];
      }
      grouped[tableNumber]!.add(order);
    }
    
    // Trier les sessions de chaque table par date (plus récent en premier)
    grouped.forEach((table, sessions) {
      sessions.sort((a, b) {
        final dateA = DateTime.tryParse(a['archivedAt'] ?? a['createdAt'] ?? '') ?? DateTime(1970);
        final dateB = DateTime.tryParse(b['archivedAt'] ?? b['createdAt'] ?? '') ?? DateTime(1970);
        return dateB.compareTo(dateA);
      });
    });
    
    return grouped;
  }
  
  /// Calcule le total d'une session (commande)
  static double calculateSessionTotal(Map<String, dynamic> order) {
    final mainNote = order['mainNote'] as Map<String, dynamic>?;
    final subNotes = order['subNotes'] as List? ?? [];
    
    double total = 0.0;
    
    // Total de la note principale
    if (mainNote != null) {
      final mainItems = mainNote['items'] as List? ?? [];
      for (final item in mainItems) {
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
        total += price * quantity;
      }
    }
    
    // Total des sous-notes
    for (final note in subNotes) {
      final items = note['items'] as List? ?? [];
      for (final item in items) {
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
        total += price * quantity;
      }
    }
    
    return total;
  }
  
  /// Groupe les commandes archivées par numéro de table (depuis processedTables)
  static Map<String, Map<String, dynamic>> groupByTableFromProcessed(
    Map<String, dynamic> processedTables,
  ) {
    return Map<String, Map<String, dynamic>>.from(processedTables);
  }
  
  /// Formate une date pour l'affichage
  static String formatDate(String? isoString) {
    if (isoString == null) return '';
    try {
      final date = DateTime.parse(isoString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoString;
    }
  }
}

