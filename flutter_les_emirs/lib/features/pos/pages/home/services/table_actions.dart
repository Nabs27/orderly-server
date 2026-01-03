import 'package:flutter/material.dart';
// import '../../../pos_order_page.dart'; // Ancienne version
import '../../order/PosOrderPage_refactor.dart' as refactor; // Version refactorisée pour test

class TableActions {
  static void openTable({
    required Map<String, List<Map<String, dynamic>>> serverTables,
    required String userName,
    required String tableId,
  }) {
    final tables = serverTables[userName] ?? [];
    final tableIndex = tables.indexWhere((t) => t['id'] == tableId);
    if (tableIndex != -1) {
      tables[tableIndex]['status'] = 'occupee';
      tables[tableIndex]['openedAt'] = DateTime.now();
      tables[tableIndex]['server'] = userName;
    }
  }

  static void closeTable({
    required Map<String, List<Map<String, dynamic>>> serverTables,
    required String tableId,
  }) {
    for (final serverName in serverTables.keys) {
      final tables = serverTables[serverName]!;
      tables.removeWhere((t) => t['id'] == tableId);
    }
  }

  static Future<void> openOrderPageFromTable({
    required BuildContext context,
    required Map<String, dynamic> table,
    required Future<void> Function() syncOrders,
    required String userName,
    String initialNoteId = 'main',
  }) async {
    try {
      await syncOrders();
      // ignore: use_build_context_synchronously
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => refactor.PosOrderPage( // Version refactorisée pour test
            tableNumber: table['number'],
            tableId: table['id'],
            // 🆕 CORRECTION : Utiliser pendingClientOrderId ou newClientOrderId si orderId est null (commandes client sans ID)
            orderId: table['orderId'] ?? table['pendingClientOrderId'] ?? table['newClientOrderId'],
            currentCovers: table['covers'] ?? 0,
            currentServer: table['server'] ?? userName,
            initialNoteId: initialNoteId,
          ),
        ),
      );
      // ignore: use_build_context_synchronously
      await syncOrders();
    } catch (e) {
      // En cas d’erreur de sync, ouvrir quand même
      // ignore: use_build_context_synchronously
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => refactor.PosOrderPage( // Version refactorisée pour test
            tableNumber: table['number'],
            tableId: table['id'],
            // 🆕 CORRECTION : Utiliser pendingClientOrderId ou newClientOrderId si orderId est null (commandes client sans ID)
            orderId: table['orderId'] ?? table['pendingClientOrderId'] ?? table['newClientOrderId'],
            currentCovers: table['covers'] ?? 0,
            currentServer: table['server'] ?? userName,
            initialNoteId: initialNoteId,
          ),
        ),
      );
    }
  }
}
