import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../../core/api_client.dart';
import '../../../models/order_note.dart';

/// Service pour gérer les actions sur les notes (ajout, modification, suppression, etc.)
class NoteActions {
  /// Sauvegarder l'état actuel dans l'historique (avant une action)
  static void saveHistoryState({
    required List<Map<String, dynamic>> actionHistory,
    required OrderNote mainNote,
    required List<OrderNote> subNotes,
    required String action,
  }) {
    final state = {
      'mainNoteItems': mainNote.items.map((item) => item.copyWith()).toList(),
      'subNotes': subNotes.map((note) => note.copyWith()).toList(),
      'mainNoteTotal': mainNote.total,
      'action': action,
    };
    
    actionHistory.add(state);
    
    // Limiter l'historique à 20 actions pour éviter trop de mémoire
    if (actionHistory.length > 20) {
      actionHistory.removeAt(0);
    }
    
    print('[UNDO] État sauvegardé - Action: $action, Historique: ${actionHistory.length}');
  }

  /// Annuler la dernière action (bouton Retour)
  static Map<String, dynamic>? undoLastAction({
    required List<Map<String, dynamic>> actionHistory,
    required BuildContext context,
  }) {
    if (actionHistory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune action à annuler'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 1),
        ),
      );
      return null;
    }
    
    // Récupérer le dernier état
    final lastState = actionHistory.removeLast();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Action annulée (${lastState['action']})'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
    
    print('[UNDO] Action annulée - ${lastState['action']}, Historique restant: ${actionHistory.length}');
    
    return {
      'mainNoteItems': lastState['mainNoteItems'] as List<OrderNoteItem>,
      'subNotes': lastState['subNotes'] as List<OrderNote>,
      'mainNoteTotal': lastState['mainNoteTotal'] as double,
    };
  }

  /// Réinitialiser les nouveaux articles (quand le serveur quitte la table)
  static void resetNewlyAddedItems({
    required Set<int> newlyAddedItems,
    required Map<int, int> newlyAddedQuantities,
  }) {
    newlyAddedItems.clear();
    newlyAddedQuantities.clear();
    print('[POS] Nouveaux articles réinitialisés');
  }

  /// Créer une sous-note
  static Future<OrderNote?> createSubNote({
    required int activeOrderId,
    required String name,
    required int noteCovers,
    required BuildContext context,
  }) async {
    try {
      // Créer la sous-note côté serveur d'abord
      final response = await ApiClient.dio.post('/orders/$activeOrderId/subnotes', data: {
        'name': name,
        'covers': noteCovers,
        'items': [],
      });

      if (response.statusCode == 201) {
        final serverData = response.data as Map<String, dynamic>;
        final createdNote = OrderNote.fromJson((serverData['subNote'] as Map<String, dynamic>));

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Note "$name" créée'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        
        return createdNote;
      } else {
        throw Exception('Erreur création sous-note côté serveur');
      }
    } catch (e) {
      print('[POS] Erreur création sous-note: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur création note: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return null;
    }
  }

  /// Ajouter un article à la note active
  static Map<String, dynamic> addItem({
    required Map<String, dynamic> item,
    required String activeNoteId,
    required OrderNote mainNote,
    required List<OrderNote> subNotes,
    required Set<int> newlyAddedItems,
    required Map<int, int> newlyAddedQuantities,
    int quantity = 1, // 🐛 BUG FIX #3 : Quantité personnalisée (par défaut 1)
  }) {
    final noteItem = OrderNoteItem(
      id: item['id'] as int,
      name: item['name'] as String,
      price: (item['price'] as num).toDouble(),
      quantity: quantity, // 🐛 BUG FIX #3 : Utiliser la quantité personnalisée
    );
    
    OrderNote updatedMainNote = mainNote;
    List<OrderNote> updatedSubNotes = List.from(subNotes);
    Set<int> updatedNewlyAddedItems = Set.from(newlyAddedItems);
    Map<int, int> updatedNewlyAddedQuantities = Map.from(newlyAddedQuantities);
    
    // Ajouter à la note active
    if (activeNoteId == 'main') {
      // Vérifier si l'article existe déjà dans la note principale
      final existingIndex = mainNote.items.indexWhere(
        (it) => it.id == noteItem.id && it.name == noteItem.name,
      );
      
      if (existingIndex != -1) {
        // Augmenter la quantité
        final updatedItems = List<OrderNoteItem>.from(mainNote.items);
        updatedItems[existingIndex] = updatedItems[existingIndex].copyWith(
          quantity: updatedItems[existingIndex].quantity + quantity, // 🐛 BUG FIX #3 : Ajouter la quantité personnalisée
        );
        updatedMainNote = mainNote.copyWith(
          items: updatedItems,
          total: mainNote.total + (noteItem.price * quantity), // 🐛 BUG FIX #3 : Multiplier par la quantité
        );
        // Marquer comme nouvellement ajouté et compter la quantité
        updatedNewlyAddedItems.add(noteItem.id);
        updatedNewlyAddedQuantities[noteItem.id] = (updatedNewlyAddedQuantities[noteItem.id] ?? 0) + quantity; // 🐛 BUG FIX #3 : Ajouter la quantité personnalisée
      } else {
        // Ajouter nouvel article
        updatedMainNote = mainNote.copyWith(
          items: [...mainNote.items, noteItem],
          total: mainNote.total + (noteItem.price * quantity), // 🐛 BUG FIX #3 : Multiplier par la quantité
        );
        // Marquer comme nouvellement ajouté et compter la quantité
        updatedNewlyAddedItems.add(noteItem.id);
        updatedNewlyAddedQuantities[noteItem.id] = quantity; // 🐛 BUG FIX #3 : Utiliser la quantité personnalisée
      }
    } else {
      // Ajouter à une sous-note
      final noteIndex = subNotes.indexWhere((n) => n.id == activeNoteId);
      if (noteIndex != -1) {
        final existingIndex = subNotes[noteIndex].items.indexWhere(
          (it) => it.id == noteItem.id && it.name == noteItem.name,
        );
        
        if (existingIndex != -1) {
          // Augmenter la quantité
          final updatedItems = List<OrderNoteItem>.from(subNotes[noteIndex].items);
          updatedItems[existingIndex] = updatedItems[existingIndex].copyWith(
            quantity: updatedItems[existingIndex].quantity + quantity, // 🐛 BUG FIX #3 : Ajouter la quantité personnalisée
          );
          updatedSubNotes[noteIndex] = subNotes[noteIndex].copyWith(
            items: updatedItems,
            total: subNotes[noteIndex].total + (noteItem.price * quantity), // 🐛 BUG FIX #3 : Multiplier par la quantité
          );
          updatedNewlyAddedItems.add(noteItem.id);
          updatedNewlyAddedQuantities[noteItem.id] = (updatedNewlyAddedQuantities[noteItem.id] ?? 0) + quantity; // 🐛 BUG FIX #3 : Ajouter la quantité personnalisée
        } else {
          // Ajouter nouvel article
          updatedSubNotes[noteIndex] = subNotes[noteIndex].copyWith(
            items: [...subNotes[noteIndex].items, noteItem],
            total: subNotes[noteIndex].total + (noteItem.price * quantity), // 🐛 BUG FIX #3 : Multiplier par la quantité
          );
          updatedNewlyAddedItems.add(noteItem.id);
          updatedNewlyAddedQuantities[noteItem.id] = quantity; // 🐛 BUG FIX #3 : Utiliser la quantité personnalisée
        }
      }
    }
    
    try { HapticFeedback.selectionClick(); } catch (_) {}
    
    return {
      'mainNote': updatedMainNote,
      'subNotes': updatedSubNotes,
      'newlyAddedItems': updatedNewlyAddedItems,
      'newlyAddedQuantities': updatedNewlyAddedQuantities,
    };
  }

  /// Mettre à jour la quantité d'un article
  static Map<String, dynamic>? updateQuantity({
    required int index,
    required int newQty,
    required String activeNoteId,
    required OrderNote activeNote,
    required OrderNote mainNote,
    required List<OrderNote> subNotes,
    required BuildContext context,
  }) {
    final item = activeNote.items[index];
    
    // PROTECTION : Ne pas modifier les articles déjà envoyés à la cuisine
    if (item.isSent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Cette ligne a déjà été envoyée à la cuisine. Elle ne peut pas être modifiée.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return null;
    }
    
    OrderNote updatedMainNote = mainNote;
    List<OrderNote> updatedSubNotes = List.from(subNotes);
    
    if (newQty <= 0) {
      // Supprimer l'article
      if (activeNoteId == 'main') {
        updatedMainNote = mainNote.copyWith(
          items: mainNote.items.where((it) => it != item).toList(),
          total: mainNote.total - (item.price * item.quantity),
        );
      } else {
        final noteIndex = subNotes.indexWhere((n) => n.id == activeNoteId);
        if (noteIndex != -1) {
          updatedSubNotes[noteIndex] = subNotes[noteIndex].copyWith(
            items: subNotes[noteIndex].items.where((it) => it != item).toList(),
            total: subNotes[noteIndex].total - (item.price * item.quantity),
          );
        }
      }
    } else {
      // Mettre à jour la quantité
      final oldTotal = item.price * item.quantity;
      final newTotal = item.price * newQty;
      
      if (activeNoteId == 'main') {
        final updatedItems = List<OrderNoteItem>.from(mainNote.items);
        updatedItems[index] = item.copyWith(quantity: newQty);
        updatedMainNote = mainNote.copyWith(
          items: updatedItems,
          total: mainNote.total - oldTotal + newTotal,
        );
      } else {
        final noteIndex = subNotes.indexWhere((n) => n.id == activeNoteId);
        if (noteIndex != -1) {
          final updatedItems = List<OrderNoteItem>.from(subNotes[noteIndex].items);
          updatedItems[index] = item.copyWith(quantity: newQty);
          updatedSubNotes[noteIndex] = subNotes[noteIndex].copyWith(
            items: updatedItems,
            total: subNotes[noteIndex].total - oldTotal + newTotal,
          );
        }
      }
    }
    
    return {
      'mainNote': updatedMainNote,
      'subNotes': updatedSubNotes,
    };
  }

  /// Supprimer une ligne
  static Map<String, dynamic>? deleteLine({
    required int index,
    required String activeNoteId,
    required OrderNote activeNote,
    required OrderNote mainNote,
    required List<OrderNote> subNotes,
    required BuildContext context,
  }) {
    final item = activeNote.items[index];
    
    // PROTECTION : Ne pas supprimer les articles déjà envoyés à la cuisine
    if (item.isSent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Cette ligne a déjà été envoyée à la cuisine. Elle ne peut pas être supprimée.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return null;
    }
    
    OrderNote updatedMainNote = mainNote;
    List<OrderNote> updatedSubNotes = List.from(subNotes);
    
    if (activeNoteId == 'main') {
      updatedMainNote = mainNote.copyWith(
        items: mainNote.items.where((it) => it != item).toList(),
        total: mainNote.total - (item.price * item.quantity),
      );
    } else {
      final noteIndex = subNotes.indexWhere((n) => n.id == activeNoteId);
      if (noteIndex != -1) {
        updatedSubNotes[noteIndex] = subNotes[noteIndex].copyWith(
          items: subNotes[noteIndex].items.where((it) => it != item).toList(),
          total: subNotes[noteIndex].total - (item.price * item.quantity),
        );
      }
    }
    
    return {
      'mainNote': updatedMainNote,
      'subNotes': updatedSubNotes,
    };
  }

  /// Vider le ticket (note active)
  static Map<String, dynamic> clearTicket({
    required String activeNoteId,
    required OrderNote mainNote,
    required List<OrderNote> subNotes,
  }) {
    OrderNote updatedMainNote = mainNote;
    List<OrderNote> updatedSubNotes = List.from(subNotes);
    
    if (activeNoteId == 'main') {
      updatedMainNote = mainNote.copyWith(items: [], total: 0.0);
    } else {
      final noteIndex = subNotes.indexWhere((n) => n.id == activeNoteId);
      if (noteIndex != -1) {
        updatedSubNotes[noteIndex] = subNotes[noteIndex].copyWith(items: [], total: 0.0);
      }
    }
    
    return {
      'mainNote': updatedMainNote,
      'subNotes': updatedSubNotes,
    };
  }
}

