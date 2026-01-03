import '../../../models/order_note.dart';

/// Service pour centraliser la logique de mise à jour locale après transferts
class LocalUpdateService {
  /// Mettre à jour l'interface locale après transfert vers une note
  static void updateAfterTransferToNote({
    required Map<int, int> selectedItems,
    required OrderNote activeNote,
    required String activeNoteId,
    required OrderNote Function() getMainNote,
    required void Function(OrderNote) setMainNote,
    required List<OrderNote> Function() getSubNotes,
    required void Function(List<OrderNote>) setSubNotes,
    required Function(void Function()) setState,
  }) {
    setState(() {
      final sortedEntries = selectedItems.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
      for (final entry in sortedEntries) {
        final item = activeNote.items[entry.key];
        if (item.quantity > entry.value) {
          item.quantity = item.quantity - entry.value;
        } else {
          if (activeNoteId == 'main') {
            final mainNote = getMainNote();
            mainNote.items.removeAt(entry.key);
            setMainNote(mainNote);
          } else {
            final subNotes = getSubNotes();
            final noteIndex = subNotes.indexWhere((n) => n.id == activeNoteId);
            if (noteIndex != -1) {
              subNotes[noteIndex].items.removeAt(entry.key);
              setSubNotes(subNotes);
            }
          }
        }
      }
    });
  }

  /// Mettre à jour l'interface locale après transfert direct d'articles
  static void updateAfterDirectTransfer({
    required Map<int, int> selectedItems,
    required OrderNote activeNote,
    required String activeNoteId,
    required OrderNote Function() getMainNote,
    required void Function(OrderNote) setMainNote,
    required List<OrderNote> Function() getSubNotes,
    required void Function(List<OrderNote>) setSubNotes,
    required Function(void Function()) setState,
  }) {
    setState(() {
      final sortedEntries = selectedItems.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
      
      for (final entry in sortedEntries) {
        final itemIndex = entry.key;
        final quantityToRemove = entry.value;
        
        if (itemIndex < activeNote.items.length) {
          final item = activeNote.items[itemIndex];
          
          if (item.quantity > quantityToRemove) {
            item.quantity -= quantityToRemove;
            
            if (activeNoteId == 'main') {
              final mainNote = getMainNote();
              setMainNote(mainNote.copyWith(
                total: mainNote.total - (item.price * quantityToRemove),
              ));
            } else {
              final subNotes = getSubNotes();
              final noteIndex = subNotes.indexWhere((n) => n.id == activeNoteId);
              if (noteIndex != -1) {
                final updatedSubNotes = List<OrderNote>.from(subNotes);
                updatedSubNotes[noteIndex] = updatedSubNotes[noteIndex].copyWith(
                  total: updatedSubNotes[noteIndex].total - (item.price * quantityToRemove),
                );
                setSubNotes(updatedSubNotes);
              }
            }
          } else {
            final itemPrice = item.price * item.quantity;
            
            if (activeNoteId == 'main') {
              final mainNote = getMainNote();
              mainNote.items.removeAt(itemIndex);
              setMainNote(mainNote.copyWith(
                total: mainNote.total - itemPrice,
              ));
            } else {
              final subNotes = getSubNotes();
              final noteIndex = subNotes.indexWhere((n) => n.id == activeNoteId);
              if (noteIndex != -1) {
                final updatedSubNotes = List<OrderNote>.from(subNotes);
                updatedSubNotes[noteIndex].items.removeAt(itemIndex);
                updatedSubNotes[noteIndex] = updatedSubNotes[noteIndex].copyWith(
                  total: updatedSubNotes[noteIndex].total - itemPrice,
                );
                setSubNotes(updatedSubNotes);
              }
            }
          }
        }
      }
    });
  }

  /// Mettre à jour l'interface locale après création de note et transfert
  static void updateAfterCreateNoteAndTransfer({
    required Map<int, int> selectedItems,
    required OrderNote activeNote,
    required String activeNoteId,
    required OrderNote Function() getMainNote,
    required void Function(OrderNote) setMainNote,
    required List<OrderNote> Function() getSubNotes,
    required void Function(List<OrderNote>) setSubNotes,
    required Function(void Function()) setState,
  }) {
    setState(() {
      final sortedEntries = selectedItems.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
      for (final entry in sortedEntries) {
        final itemIndex = entry.key;
        if (itemIndex < activeNote.items.length) {
          final item = activeNote.items[itemIndex];
          if (item.quantity > entry.value) {
            item.quantity = item.quantity - entry.value;
          } else {
            if (activeNoteId == 'main') {
              final mainNote = getMainNote();
              mainNote.items.removeAt(itemIndex);
              setMainNote(mainNote);
            } else {
              final subNotes = getSubNotes();
              final noteIndex = subNotes.indexWhere((n) => n.id == activeNoteId);
              if (noteIndex != -1 && itemIndex < subNotes[noteIndex].items.length) {
                final updatedSubNotes = List<OrderNote>.from(subNotes);
                updatedSubNotes[noteIndex].items.removeAt(itemIndex);
                setSubNotes(updatedSubNotes);
              }
            }
          }
        }
      }
    });
  }
}

