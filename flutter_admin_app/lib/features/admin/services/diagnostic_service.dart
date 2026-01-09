import 'package:dio/dio.dart';
import '../../../core/api_client.dart';

/// Service de diagnostic pour comparer les données entre différentes sources
/// Permet de diagnostiquer les incohérences entre :
/// - Historique plan de table (history-unified)
/// - KPI POS (report-x)
/// - App Cloud (report-x)
class DiagnosticService {
  static const bool ENABLE_DIAGNOSTIC = true; // Activer/désactiver le diagnostic
  
  /// Collecter toutes les données pour une table spécifique
  static Future<Map<String, dynamic>> diagnoseTable(String tableNumber) async {
    if (!ENABLE_DIAGNOSTIC) return {};
    
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    
    // 🆕 CORRECTION WEB : Utiliser Map<String, dynamic> explicitement pour éviter LinkedMap
    final diagnosticData = <String, dynamic>{
      'table': tableNumber,
      'timestamp': now.toIso8601String(),
      'dateFrom': start.toIso8601String(),
      'dateTo': end.toIso8601String(),
      'sources': <String, dynamic>{},
    };
    
    // Source 1 : Report-X (KPI)
    try {
      final response = await ApiClient.dio.get(
        '/api/admin/report-x',
        queryParameters: {
          'dateFrom': start.toIso8601String(),
          'dateTo': end.toIso8601String(),
          'period': 'ALL',
        },
        options: Options(
          headers: {'x-admin-token': 'admin123'},
        ),
      );
      
      // 🆕 CORRECTION : Convertir Map<dynamic, dynamic> en Map<String, dynamic>
      final reportDataRaw = response.data;
      final reportData = reportDataRaw is Map
          ? Map<String, dynamic>.from(reportDataRaw as Map)
          : <String, dynamic>{};
      final paidPayments = (reportData['paidPayments'] as List<dynamic>?) ?? [];
      
      // Filtrer pour la table spécifique
      final tablePayments = paidPayments.where((p) {
        // 🆕 CORRECTION WEB : Convertir p en Map<String, dynamic> pour éviter LinkedMap
        final pMap = p is Map ? Map<String, dynamic>.from(p as Map) : <String, dynamic>{};
        final table = pMap['table']?.toString() ?? '?';
        return table == tableNumber;
      }).toList();
      
      (diagnosticData['sources'] as Map<String, dynamic>)['report_x'] = {
        'raw': reportData,
        'paidPayments_all_count': paidPayments.length,
        'paidPayments_table_count': tablePayments.length,
        'paidPayments': _extractPaymentDetails(tablePayments),
        'summary': _calculatePaymentSummary(tablePayments),
      };
    } catch (e) {
      (diagnosticData['sources'] as Map<String, dynamic>)['report_x'] = {'error': e.toString()};
    }
    
    // Source 2 : History Unified (Plan de table)
    try {
      // 🆕 CORRECTION : history-unified ne gère pas 'ALL', il faut utiliser le serveur réel
      // On récupère le serveur depuis report_x si disponible, sinon on essaie 'ALL' en dernier recours
      String? serverForHistory = 'ALL';
      try {
        final reportXData = (diagnosticData['sources'] as Map<String, dynamic>)['report_x'] as Map<String, dynamic>?;
        final paidPayments = reportXData?['paidPayments'] as List<dynamic>?;
        if (paidPayments != null && paidPayments.isNotEmpty) {
          final firstPayment = paidPayments.first;
          final firstPaymentMap = firstPayment is Map ? Map<String, dynamic>.from(firstPayment as Map) : <String, dynamic>{};
          serverForHistory = firstPaymentMap['server']?.toString();
        }
      } catch (_) {
        // Ignorer l'erreur, on utilisera 'ALL'
      }
      
      // Récupérer pour le serveur trouvé (ou 'ALL' si pas trouvé)
      final response = await ApiClient.dio.get(
        '/api/pos/history-unified',
        queryParameters: {
          'server': serverForHistory ?? 'ALL',
        },
      );
      
      // 🆕 CORRECTION : Convertir Map<dynamic, dynamic> en Map<String, dynamic>
      final historyDataRaw = response.data;
      final historyData = historyDataRaw is Map
          ? Map<String, dynamic>.from(historyDataRaw as Map)
          : <String, dynamic>{};
      final ordersRaw = historyData['orders'];
      final orders = ordersRaw is List ? List<dynamic>.from(ordersRaw) : <dynamic>[];
      final processedTablesRaw = historyData['processedTables'];
      final processedTables = processedTablesRaw is Map
          ? Map<String, dynamic>.from(processedTablesRaw as Map)
          : <String, dynamic>{};
      
      // Filtrer pour la table spécifique
      final tableOrders = orders.where((o) {
        // 🆕 CORRECTION WEB : Convertir o en Map<String, dynamic> pour éviter LinkedMap
        final oMap = o is Map ? Map<String, dynamic>.from(o as Map) : <String, dynamic>{};
        final table = oMap['table']?.toString() ?? '?';
        return table == tableNumber;
      }).toList();
      
      final tableProcessedRaw = processedTables[tableNumber];
      final tableProcessed = tableProcessedRaw is Map
          ? Map<String, dynamic>.from(tableProcessedRaw as Map)
          : null;
      
      (diagnosticData['sources'] as Map<String, dynamic>)['history_unified'] = {
        'raw': historyData,
        'orders_all_count': orders.length,
        'orders_table_count': tableOrders.length,
        'table_processed': tableProcessed != null ? _extractTableProcessed(tableProcessed) : null,
        'orders': _extractOrderDetails(tableOrders),
        'summary': _calculateHistorySummary(tableOrders, tableProcessed),
      };
    } catch (e) {
      (diagnosticData['sources'] as Map<String, dynamic>)['history_unified'] = {'error': e.toString()};
    }
    
    // Source 3 : Orders direct (pour comparaison)
    // ⚠️ NOTE : /orders ne retourne que les commandes actives (non archivées)
    // Les commandes payées sont archivées, donc cette source peut être vide même si report_x trouve des paiements
    try {
      final response = await ApiClient.dio.get('/orders');
      // 🆕 CORRECTION : Convertir List<dynamic> correctement
      final ordersRaw = response.data;
      final orders = ordersRaw is List
          ? List<dynamic>.from(ordersRaw)
          : <dynamic>[];
      
      // Filtrer pour la table spécifique
      final tableOrders = orders.where((o) {
        // 🆕 CORRECTION WEB : Convertir o en Map<String, dynamic> pour éviter LinkedMap
        final oMap = o is Map ? Map<String, dynamic>.from(o as Map) : <String, dynamic>{};
        final table = oMap['table']?.toString() ?? '?';
        return table == tableNumber;
      }).toList();
      
      (diagnosticData['sources'] as Map<String, dynamic>)['orders_direct'] = {
        'orders_all_count': orders.length,
        'orders_table_count': tableOrders.length,
        'orders': _extractOrderDetails(tableOrders),
        'summary': _calculateOrdersSummary(tableOrders),
        'note': '⚠️ Cette source ne contient que les commandes actives (non archivées). Les commandes payées sont archivées.',
      };
    } catch (e) {
      (diagnosticData['sources'] as Map<String, dynamic>)['orders_direct'] = {'error': e.toString()};
    }
    
    // Comparer les sources
    final sourcesRaw = diagnosticData['sources'];
    final sources = sourcesRaw is Map
        ? Map<String, dynamic>.from(sourcesRaw as Map)
        : <String, dynamic>{};
    diagnosticData['comparison'] = _compareSources(sources);
    
    return diagnosticData;
  }
  
  /// Extraire les détails des paiements
  static List<Map<String, dynamic>> _extractPaymentDetails(List<dynamic> payments) {
    return payments.map((p) {
      // 🆕 CORRECTION WEB : Convertir p en Map<String, dynamic> pour éviter LinkedMap
      final pMap = p is Map ? Map<String, dynamic>.from(p as Map) : <String, dynamic>{};
      
      final ticketRaw = pMap['ticket'];
      final ticket = ticketRaw is Map ? Map<String, dynamic>.from(ticketRaw as Map) : null;
      final paymentDetailsRaw = ticket?['paymentDetails'];
      final paymentDetails = paymentDetailsRaw is List ? List<dynamic>.from(paymentDetailsRaw) : null;
      
      final orderIdsRaw = pMap['orderIds'];
      final orderIds = orderIdsRaw is List ? (orderIdsRaw as List).map((e) => e.toString()).toList() : null;
      
      final splitPaymentAmountsRaw = pMap['splitPaymentAmounts'];
      final splitPaymentAmounts = splitPaymentAmountsRaw is List
          ? (splitPaymentAmountsRaw as List).map((s) {
              final sMap = s is Map ? Map<String, dynamic>.from(s as Map) : <String, dynamic>{};
              return <String, dynamic>{
                'mode': sMap['mode']?.toString() ?? '?',
                'amount': (sMap['amount'] as num?)?.toDouble() ?? 0.0,
                'clientName': sMap['clientName']?.toString(),
              };
            }).toList()
          : null;
      
      return <String, dynamic>{
        'orderId': pMap['orderId'],
        'orderIds': orderIds,
        'timestamp': pMap['timestamp']?.toString() ?? '?',
        'paymentMode': pMap['paymentMode']?.toString() ?? '?',
        'isSplitPayment': pMap['isSplitPayment'] == true,
        'splitPaymentId': pMap['splitPaymentId']?.toString(),
        'amount': (pMap['amount'] as num?)?.toDouble() ?? 0.0,
        'subtotal': (pMap['subtotal'] as num?)?.toDouble() ?? 0.0,
        'discountAmount': (pMap['discountAmount'] as num?)?.toDouble() ?? 0.0,
        'enteredAmount': (pMap['enteredAmount'] as num?)?.toDouble(),
        'allocatedAmount': (pMap['allocatedAmount'] as num?)?.toDouble(),
        'excessAmount': (pMap['excessAmount'] as num?)?.toDouble(),
        'hasCashInPayment': pMap['hasCashInPayment'] == true,
        'server': pMap['server']?.toString() ?? '?',
        'covers': pMap['covers'] ?? 1,
        'items_count': (pMap['items'] as List<dynamic>?)?.length ?? 0,
        'ticket': ticket != null ? <String, dynamic>{
          'total': (ticket['total'] as num?)?.toDouble() ?? 0.0,
          'subtotal': (ticket['subtotal'] as num?)?.toDouble() ?? 0.0,
          'discountAmount': (ticket['discountAmount'] as num?)?.toDouble() ?? 0.0,
          'totalAmount': (ticket['totalAmount'] as num?)?.toDouble(),
          'excessAmount': (ticket['excessAmount'] as num?)?.toDouble(),
          'paymentDetails': paymentDetails,
          'items_count': (ticket['items'] as List<dynamic>?)?.length ?? 0,
        } : null,
        'splitPaymentAmounts': splitPaymentAmounts,
      };
    }).toList();
  }
  
  /// Calculer le résumé des paiements
  static Map<String, dynamic> _calculatePaymentSummary(List<dynamic> payments) {
    double totalAmount = 0.0;
    double totalSubtotal = 0.0;
    double totalDiscount = 0.0;
    double totalEntered = 0.0;
    double totalExcess = 0.0;
    int splitPaymentsCount = 0;
    final modes = <String, int>{};
    final orderIds = <String>{};
    
    for (final p in payments) {
      // 🆕 CORRECTION WEB : Convertir p en Map<String, dynamic> pour éviter LinkedMap
      final pMap = p is Map ? Map<String, dynamic>.from(p as Map) : <String, dynamic>{};
      
      totalAmount += (pMap['amount'] as num?)?.toDouble() ?? 0.0;
      totalSubtotal += (pMap['subtotal'] as num?)?.toDouble() ?? 0.0;
      totalDiscount += (pMap['discountAmount'] as num?)?.toDouble() ?? 0.0;
      
      final entered = (pMap['enteredAmount'] as num?)?.toDouble();
      if (entered != null) totalEntered += entered;
      
      final excess = (pMap['excessAmount'] as num?)?.toDouble();
      if (excess != null && excess > 0.01) totalExcess += excess;
      
      if (pMap['isSplitPayment'] == true) splitPaymentsCount++;
      
      final mode = pMap['paymentMode']?.toString() ?? '?';
      modes[mode] = (modes[mode] ?? 0) + 1;
      
      final oidsRaw = pMap['orderIds'];
      final oids = oidsRaw is List ? (oidsRaw as List).map((e) => e.toString()).toList() : <String>[];
      orderIds.addAll(oids);
    }
    
    return {
      'payments_count': payments.length,
      'totalAmount': totalAmount,
      'totalSubtotal': totalSubtotal,
      'totalDiscount': totalDiscount,
      'totalEntered': totalEntered > 0 ? totalEntered : null,
      'totalExcess': totalExcess > 0.01 ? totalExcess : null,
      'splitPayments_count': splitPaymentsCount,
      'modes': modes,
      'orderIds': orderIds.toList()..sort(),
      'tickets_count': payments.length, // Un paiement = un ticket dans report-x
    };
  }
  
  /// Extraire les détails des commandes
  static List<Map<String, dynamic>> _extractOrderDetails(List<dynamic> orders) {
    return orders.map((o) {
      // 🆕 CORRECTION WEB : Convertir o en Map<String, dynamic> pour éviter LinkedMap
      final oMap = o is Map ? Map<String, dynamic>.from(o as Map) : <String, dynamic>{};
      
      final paymentHistoryRaw = oMap['paymentHistory'];
      final paymentHistory = paymentHistoryRaw is List ? List<dynamic>.from(paymentHistoryRaw) : <dynamic>[];
      
      return <String, dynamic>{
        'orderId': oMap['id']?.toString() ?? '?',
        'table': oMap['table']?.toString() ?? '?',
        'server': oMap['server']?.toString() ?? '?',
        'status': oMap['status']?.toString() ?? '?',
        'createdAt': oMap['createdAt']?.toString() ?? '?',
        'archivedAt': oMap['archivedAt']?.toString(),
        'total': (oMap['total'] as num?)?.toDouble() ?? 0.0,
        'paymentHistory_count': paymentHistory.length,
        'paymentHistory': paymentHistory.map((p) {
          final pMap = p is Map ? Map<String, dynamic>.from(p as Map) : <String, dynamic>{};
          return <String, dynamic>{
            'timestamp': pMap['timestamp']?.toString() ?? '?',
            'paymentMode': pMap['paymentMode']?.toString() ?? '?',
            'amount': (pMap['amount'] as num?)?.toDouble() ?? 0.0,
            'isSplitPayment': pMap['isSplitPayment'] == true,
            'splitPaymentId': pMap['splitPaymentId']?.toString(),
          };
        }).toList(),
      };
    }).toList();
  }
  
  /// Extraire les données traitées d'une table
  static Map<String, dynamic> _extractTableProcessed(Map<String, dynamic> tableProcessed) {
    final sessionsRaw = tableProcessed['sessions'];
    final sessions = sessionsRaw is List
        ? List<dynamic>.from(sessionsRaw)
        : <dynamic>[];
    final servicesRaw = tableProcessed['services'];
    final services = servicesRaw is Map
        ? Map<String, dynamic>.from(servicesRaw as Map)
        : <String, dynamic>{};
    
    final servicesList = <Map<String, dynamic>>[];
    services.forEach((serviceIndex, serviceData) {
      // 🆕 CORRECTION WEB : Convertir serviceData en Map<String, dynamic> pour éviter LinkedMap
      final serviceMap = serviceData is Map ? Map<String, dynamic>.from(serviceData as Map) : <String, dynamic>{};
      servicesList.add({
        'serviceIndex': serviceIndex,
        'total': (serviceMap['total'] as num?)?.toDouble() ?? 0.0,
        'sessions_count': (serviceMap['sessions'] as List<dynamic>?)?.length ?? 0,
      });
    });
    
    return {
      'sessions_count': sessions.length,
      'services_count': services.length,
      'services': servicesList,
    };
  }
  
  /// Calculer le résumé de l'historique
  static Map<String, dynamic> _calculateHistorySummary(List<dynamic> orders, Map<String, dynamic>? processed) {
    double totalAmount = 0.0;
    final orderIds = <String>{};
    
    for (final o in orders) {
      // 🆕 CORRECTION WEB : Convertir o en Map<String, dynamic> pour éviter LinkedMap
      final oMap = o is Map ? Map<String, dynamic>.from(o as Map) : <String, dynamic>{};
      
      totalAmount += (oMap['total'] as num?)?.toDouble() ?? 0.0;
      final id = oMap['id']?.toString();
      if (id != null) orderIds.add(id);
    }
    
    final servicesCount = (processed?['services'] as Map<String, dynamic>?)?.length ?? 0;
    
    return {
      'orders_count': orders.length,
      'totalAmount': totalAmount,
      'orderIds': orderIds.toList()..sort(),
      'services_count': servicesCount,
    };
  }
  
  /// Calculer le résumé des commandes directes
  static Map<String, dynamic> _calculateOrdersSummary(List<dynamic> orders) {
    double totalAmount = 0.0;
    final orderIds = <String>{};
    
    for (final o in orders) {
      // 🆕 CORRECTION WEB : Convertir o en Map<String, dynamic> pour éviter LinkedMap
      final oMap = o is Map ? Map<String, dynamic>.from(o as Map) : <String, dynamic>{};
      
      totalAmount += (oMap['total'] as num?)?.toDouble() ?? 0.0;
      final id = oMap['id']?.toString();
      if (id != null) orderIds.add(id);
    }
    
    return {
      'orders_count': orders.length,
      'totalAmount': totalAmount,
      'orderIds': orderIds.toList()..sort(),
    };
  }
  
  /// Comparer les sources et détecter les différences
  static Map<String, dynamic> _compareSources(Map<String, dynamic> sources) {
    final reportXRaw = sources['report_x'];
    final reportX = reportXRaw is Map ? Map<String, dynamic>.from(reportXRaw as Map) : null;
    final historyRaw = sources['history_unified'];
    final history = historyRaw is Map ? Map<String, dynamic>.from(historyRaw as Map) : null;
    final ordersRaw = sources['orders_direct'];
    final orders = ordersRaw is Map ? Map<String, dynamic>.from(ordersRaw as Map) : null;
    
    final reportXSummaryRaw = reportX?['summary'];
    final reportXSummary = reportXSummaryRaw is Map ? Map<String, dynamic>.from(reportXSummaryRaw as Map) : null;
    final historySummaryRaw = history?['summary'];
    final historySummary = historySummaryRaw is Map ? Map<String, dynamic>.from(historySummaryRaw as Map) : null;
    final ordersSummaryRaw = orders?['summary'];
    final ordersSummary = ordersSummaryRaw is Map ? Map<String, dynamic>.from(ordersSummaryRaw as Map) : null;
    
    final differences = <String, dynamic>{};
    
    // Comparer les montants
    final reportXAmount = (reportXSummary?['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final historyAmount = (historySummary?['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final ordersAmount = (ordersSummary?['totalAmount'] as num?)?.toDouble() ?? 0.0;
    
    if ((reportXAmount - historyAmount).abs() > 0.01 ||
        (reportXAmount - ordersAmount).abs() > 0.01) {
      differences['amounts'] = {
        'report_x': reportXAmount,
        'history_unified': historyAmount,
        'orders_direct': ordersAmount,
        'difference': (reportXAmount - historyAmount).abs(),
      };
    }
    
    // Comparer les nombres de paiements/tickets
    final reportXPayments = (reportXSummary?['payments_count'] as int?) ?? 0;
    final historyServices = (historySummary?['services_count'] as int?) ?? 0;
    
    if (reportXPayments != historyServices) {
      differences['counts'] = {
        'report_x_payments': reportXPayments,
        'history_services': historyServices,
        'difference': (reportXPayments - historyServices).abs(),
      };
    }
    
    // Comparer les orderIds
    final reportXOrderIds = (reportXSummary?['orderIds'] as List<dynamic>?)?.cast<String>() ?? [];
    final historyOrderIds = (historySummary?['orderIds'] as List<dynamic>?)?.cast<String>() ?? [];
    final ordersOrderIds = (ordersSummary?['orderIds'] as List<dynamic>?)?.cast<String>() ?? [];
    
    final allOrderIds = <String>{
      ...reportXOrderIds,
      ...historyOrderIds,
      ...ordersOrderIds,
    };
    
    final missingInReportX = historyOrderIds.where((id) => !reportXOrderIds.contains(id)).toList();
    final missingInHistory = reportXOrderIds.where((id) => !historyOrderIds.contains(id)).toList();
    
    if (missingInReportX.isNotEmpty || missingInHistory.isNotEmpty) {
      differences['orderIds'] = {
        'report_x': reportXOrderIds,
        'history_unified': historyOrderIds,
        'orders_direct': ordersOrderIds,
        'missing_in_report_x': missingInReportX,
        'missing_in_history': missingInHistory,
      };
    }
    
    // Comparer les pourboires
    final reportXExcess = (reportXSummary?['totalExcess'] as num?)?.toDouble();
    if (reportXExcess != null && reportXExcess > 0.01) {
      differences['tips'] = {
        'report_x_excess': reportXExcess,
        'present': true,
      };
    }
    
    return {
      'differences': differences,
      'differences_count': differences.length,
      'all_orderIds': allOrderIds.toList()..sort(),
    };
  }
  
  /// Formater le montant
  static String _formatCurrency(double value) {
    return value.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    ) + ' TND';
  }
  
  /// Générer un rapport texte pour la console
  static String generateTextReport(Map<String, dynamic> diagnosticData) {
    final buffer = StringBuffer();
    final table = diagnosticData['table']?.toString() ?? '?';
    
    buffer.writeln('\n${'=' * 70}');
    buffer.writeln('🔍 DIAGNOSTIC TABLE $table');
    buffer.writeln('Timestamp: ${diagnosticData['timestamp']}');
    buffer.writeln('${'=' * 70}\n');
    
    final sources = diagnosticData['sources'] as Map<String, dynamic>? ?? {};
    
    // Source Report-X
    final reportX = sources['report_x'] as Map<String, dynamic>?;
    if (reportX != null) {
      if (reportX.containsKey('error')) {
        buffer.writeln('❌ REPORT-X: Erreur - ${reportX['error']}');
      } else {
        final summary = reportX['summary'] as Map<String, dynamic>?;
        buffer.writeln('📊 SOURCE 1: Report-X (KPI)');
        buffer.writeln('  - Paiements trouvés: ${summary?['payments_count'] ?? 0}');
        buffer.writeln('  - Montant total: ${_formatCurrency(summary?['totalAmount'] ?? 0.0)}');
        buffer.writeln('  - Subtotal: ${_formatCurrency(summary?['totalSubtotal'] ?? 0.0)}');
        buffer.writeln('  - Remise: ${_formatCurrency(summary?['totalDiscount'] ?? 0.0)}');
        if (summary?['totalEntered'] != null) {
          buffer.writeln('  - Montant encaissé: ${_formatCurrency(summary?['totalEntered'])}');
        }
        if (summary?['totalExcess'] != null) {
          buffer.writeln('  - Pourboire: ${_formatCurrency(summary?['totalExcess'])}');
        }
        buffer.writeln('  - Paiements divisés: ${summary?['splitPayments_count'] ?? 0}');
        buffer.writeln('  - Modes: ${summary?['modes']}');
        buffer.writeln('  - OrderIds: ${summary?['orderIds']}');
        buffer.writeln('');
      }
    }
    
    // Source History Unified
    final historyRaw = sources['history_unified'];
    final history = historyRaw is Map ? Map<String, dynamic>.from(historyRaw as Map) : null;
    if (history != null) {
      if (history.containsKey('error')) {
        buffer.writeln('❌ HISTORY-UNIFIED: Erreur - ${history['error']}');
      } else {
        final summaryRaw = history['summary'];
        final summary = summaryRaw is Map ? Map<String, dynamic>.from(summaryRaw as Map) : null;
        buffer.writeln('📋 SOURCE 2: History Unified (Plan de table)');
        buffer.writeln('  - Commandes trouvées: ${summary?['orders_count'] ?? 0}');
        buffer.writeln('  - Montant total: ${_formatCurrency(summary?['totalAmount'] ?? 0.0)}');
        buffer.writeln('  - Services détectés: ${summary?['services_count'] ?? 0}');
        buffer.writeln('  - OrderIds: ${summary?['orderIds']}');
        buffer.writeln('');
      }
    }
    
    // Comparaison
    final comparisonRaw = diagnosticData['comparison'];
    final comparison = comparisonRaw is Map ? Map<String, dynamic>.from(comparisonRaw as Map) : null;
    if (comparison != null) {
      final differencesRaw = comparison['differences'];
      final differences = differencesRaw is Map ? Map<String, dynamic>.from(differencesRaw as Map) : <String, dynamic>{};
      buffer.writeln('🔍 COMPARAISON');
      buffer.writeln('  - Différences détectées: ${comparison['differences_count'] ?? 0}');
      buffer.writeln('');
      
      if (differences.isNotEmpty) {
        buffer.writeln('⚠️ DIFFÉRENCES:');
        differences.forEach((key, value) {
          buffer.writeln('  - $key: $value');
        });
      } else {
        buffer.writeln('✅ Aucune différence détectée');
      }
    }
    
    buffer.writeln('\n${'=' * 70}\n');
    
    return buffer.toString();
  }
  
  /// Logger le diagnostic dans la console
  static void logDiagnostic(Map<String, dynamic> diagnosticData) {
    if (!ENABLE_DIAGNOSTIC) return;
    print(generateTextReport(diagnosticData));
  }
}
