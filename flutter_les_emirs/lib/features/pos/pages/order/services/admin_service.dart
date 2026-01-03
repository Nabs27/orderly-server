import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../../../../core/api_client.dart';

/// Service pour les opérations d'administration
class AdminService {
  /// Nettoyer les doublons de sous-notes
  static Future<void> cleanupDuplicates({
    required String currentTableNumber,
    required BuildContext context,
    required Function() loadExistingOrder,
  }) async {
    try {
      final response = await ApiClient.dio.post('/api/admin/cleanup-duplicate-notes', 
        data: {'table': currentTableNumber},
        options: Options(headers: {'x-admin-token': 'admin123'})
      );
      
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final duplicatesRemoved = data['duplicatesRemoved'] ?? 0;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nettoyage terminé: $duplicatesRemoved doublons supprimés'),
            backgroundColor: Colors.green,
          ),
        );
        
        await loadExistingOrder();
      }
    } catch (e) {
      print('[POS] Erreur nettoyage doublons: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du nettoyage: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

