import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../../../../core/api_client.dart';
import '../../../models/order_note.dart';

/// Service pour gérer la logique de paiement
class PaymentService {
  /// Récupérer toutes les commandes pour le paiement
  static Future<List<Map<String, dynamic>>?> getAllOrdersForTable(String tableNumber) async {
    try {
      final res = await ApiClient.dio.get('/orders', queryParameters: {'table': tableNumber});
      final orders = (res.data as List).cast<Map<String, dynamic>>();
      print('[PAYMENT] ${orders.length} commandes trouvées pour table $tableNumber');
      return orders;
    } catch (e) {
      print('[PAYMENT] Erreur récupération commandes: $e');
      return null;
    }
  }

  /// Mise à jour optimiste des données après paiement
  static void updateDataOptimistically({
    required Map<String, dynamic> paymentResult,
    required BuildContext context,
    required Function(void Function()) setState,
    required OrderNote Function() getMainNote,
    required void Function(OrderNote) setMainNote,
    required List<OrderNote> Function() getSubNotes,
    required void Function(List<OrderNote>) setSubNotes,
    required String Function() getActiveNoteId,
    required void Function(String) setActiveNoteId,
    required Future<void> Function() loadExistingOrder,
  }) {
    try {
      final paymentType = paymentResult['payment_type'] as String?;
      final paidAmount = paymentResult['paid_amount'] as double? ?? 0.0;
      
      print('[POS] Mise à jour optimiste après paiement: $paymentType, montant: $paidAmount');
      
      // Utiliser Future.microtask pour éviter setState pendant un build
      Future.microtask(() {
        if (!context.mounted) return;
        
        setState(() {
          final currentMainNote = getMainNote();
          final currentSubNotes = getSubNotes();
          
          if (paymentType == 'all') {
            setMainNote(OrderNote(
              id: 'main',
              name: 'Note Principale',
              covers: 1,
              items: [],
              total: 0.0,
            ));
            setSubNotes([]);
            setActiveNoteId('main');
            print('[POS] Table vidée après paiement complet');
            
          } else if (paymentType == 'main') {
            setMainNote(OrderNote(
              id: 'main',
              name: 'Note Principale',
              covers: currentMainNote.covers,
              items: [],
              total: 0.0,
            ));
            print('[POS] Note principale vidée après paiement');
            
          } else if (paymentType?.startsWith('sub_') == true) {
            // 🆕 Ne plus supprimer la sous-note, recharger les données depuis le serveur
            // La sous-note sera toujours présente mais marquée comme payée
            print('[POS] Sous-note $paymentType payée, rechargement des données');
            loadExistingOrder().then((_) {
              print('[POS] Données rechargées après paiement sous-note');
            });
            
          } else if (paymentType == 'partial') {
            print('[POS] Paiement partiel traité, rechargement des données pour mise à jour');
            loadExistingOrder().then((_) {
              print('[POS] Données rechargées après paiement partiel');
            });
          }
        });
        
        // Afficher un feedback utilisateur
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(paymentType == 'all' 
                ? 'Paiement complet effectué ✓' 
                : paymentType == 'partial'
                  ? 'Paiement partiel effectué ✓'
                  : 'Note payée ✓'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      });
    } catch (e) {
      print('[POS] Erreur mise à jour optimiste: $e');
    }
  }
}

