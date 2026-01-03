import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../../core/api_client.dart';

class AdminActions {
  static Future<void> testApiConnection(BuildContext context) async {
    try {
      final response = await ApiClient.dio.get('/health');
      final adminResponse = await ApiClient.dio.post('/api/admin/login', data: {'password': 'admin123'});
      final simResponse = await ApiClient.dio.post(
        '/api/admin/simulate-data',
        data: {'mode': 'once', 'servers': ['MOHAMED']},
        options: Options(headers: {'x-admin-token': 'admin123'}),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Health ${response.statusCode}, Login ${adminResponse.statusCode}, Sim ${simResponse.statusCode}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur API: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  static Future<void> runSimulation(
    BuildContext context,
    String mode,
    Future<void> Function() onSync,
    Future<void> Function() onSaveTables,
  ) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [CircularProgressIndicator(), SizedBox(width: 16), Text('Génération des données...')],
          ),
        ),
      );

      final response = await ApiClient.dio.post(
        '/api/admin/simulate-data',
        data: {
          'mode': mode,
          'servers': ['MOHAMED', 'ALI', 'FATMA'],
          'progressive': mode == 'progressive',
        },
        options: Options(headers: {'x-admin-token': 'admin123'}),
      );

      if (context.mounted) Navigator.of(context).pop();

      if (response.statusCode == 200) {
        final generated = (response.data as Map<String, dynamic>)['generated'] as Map<String, dynamic>;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Simulation OK: ${generated['orders']} cmd, ${generated['totalTables']} tables'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await onSync();
        await onSaveTables();
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur simulation: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  static Future<void> resetSystem(
    BuildContext context,
    Future<void> Function() clearLocalStorage,
    Future<void> Function() afterReset,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('⚠️ Remettre à zéro'),
        content: const Text('Supprimer toutes les données (commandes, factures, historiques) ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Oui')),
        ],
      ),
    );
    if (confirmed != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(width: 16), Text('Remise à zéro en cours...')]),
      ),
    );

    try {
      final response = await ApiClient.dio.post('/api/admin/full-reset', options: Options(headers: {'x-admin-token': 'admin123'}));
      await clearLocalStorage();
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Système remis à zéro: ${response.data['message']}'), backgroundColor: Colors.green),
        );
      }
      await afterReset();
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur remise à zéro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  static Future<void> clearHistory(
    BuildContext context,
    Future<void> Function() clearLocalStorage,
    VoidCallback afterLocalClear,
  ) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nettoyage en cours...'), backgroundColor: Colors.orange, duration: Duration(seconds: 30)),
      );
      final response = await ApiClient.dio.post('/api/admin/full-reset', options: Options(headers: {'x-admin-token': 'admin123'}));
      await clearLocalStorage();
      afterLocalClear();
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nettoyage terminé: ${response.data['message']}'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur nettoyage: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
