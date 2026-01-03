import 'package:flutter/material.dart';
import '../../../models/order_note.dart';

/// Helpers pour la gestion des notes et UI
class OrderHelpers {
  /// Couleurs pour les notes
  static final List<Color> noteColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.amber,
  ];

  /// Obtenir la couleur d'une note
  static Color getNoteColor(String noteId, List<OrderNote> subNotes) {
    if (noteId == 'main') return noteColors[0];
    final index = subNotes.indexWhere((n) => n.id == noteId);
    if (index == -1) return noteColors[0];
    return noteColors[(index + 1) % noteColors.length];
  }

  /// Obtenir la note active
  static OrderNote getActiveNote(String activeNoteId, OrderNote mainNote, List<OrderNote> subNotes) {
    if (activeNoteId == 'main') {
      print('[POS] Note active: main, total: ${mainNote.total}');
      return mainNote;
    }
    final note = subNotes.firstWhere(
      (note) => note.id == activeNoteId,
      orElse: () => mainNote,
    );
    print('[POS] Note active: ${note.id} (${note.name}), total: ${note.total}, items: ${note.items.length}');
    return note;
  }

  /// Calculer le total de toutes les notes
  static double calculateTotalAmount(OrderNote mainNote, List<OrderNote> subNotes) {
    double total = mainNote.total;
    for (final note in subNotes) {
      if (!note.paid) {
        total += note.total;
      }
    }
    return total;
  }
}

