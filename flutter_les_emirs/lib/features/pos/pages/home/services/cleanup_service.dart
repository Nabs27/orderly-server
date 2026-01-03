import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../../../core/api_client.dart';

class CleanupService {
  static Future<void> confirmDeleteTable({
    required BuildContext context,
    required Map<String, dynamic> table,
    required Map<String, List<Map<String, dynamic>>> serverTables,
    required Future<void> Function() saveTables,
  }) async {
    final tableNumber = table['number'] as String;
    final orderTotal = (table['orderTotal'] as num?)?.toDouble() ?? 0.0;
    final hasOrder = orderTotal > 0;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer Table N° $tableNumber ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasOrder) ...[
              const Text('⚠️ ATTENTION: Cette table a une commande en cours !'),
              const SizedBox(height: 8),
              Text('Total: ${orderTotal.toStringAsFixed(2)} TND'),
              const SizedBox(height: 8),
              const Text('Êtes-vous sûr de vouloir supprimer cette table ?'),
            ] else ...[
              const Text('Cette table sera définitivement supprimée.'),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_forever),
            label: const Text('Supprimer'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (hasOrder) {
        await ApiClient.dio.post('/api/admin/clear-table-consumption',
            data: {'table': tableNumber}, options: Options(headers: {'x-admin-token': 'admin123'}));
      }
      final tableId = table['id'] as String;
      for (final serverName in serverTables.keys) {
        final tables = serverTables[serverName]!;
        tables.removeWhere((t) => t['id'] == tableId || t['number'] == tableNumber);
      }
      await saveTables();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Table N° $tableNumber supprimée définitivement'), backgroundColor: Colors.green, duration: const Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur suppression: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 3)),
        );
      }
    }
  }

  static Future<int> cleanupEmptyTables({
    required BuildContext context,
    required List<Map<String, dynamic>> emptyTables,
    required Map<String, List<Map<String, dynamic>>> serverTables,
    required Future<void> Function() saveTables,
  }) async {
    int cleanedCount = 0;
    for (final table in emptyTables) {
      try {
        final tableId = table['id'] as String;
        final tableNumber = table['number'] as String;
        for (final serverName in serverTables.keys) {
          final tables = serverTables[serverName]!;
          tables.removeWhere((t) => t['id'] == tableId || t['number'] == tableNumber);
        }
        cleanedCount++;
      } catch (_) {}
    }
    await saveTables();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$cleanedCount table(s) vide(s) supprimée(s) définitivement'), backgroundColor: Colors.green, duration: const Duration(seconds: 2)),
      );
    }
    return cleanedCount;
  }
}
