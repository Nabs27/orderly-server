import 'package:flutter/material.dart';
import '../../../models/order_note.dart';

class NoteSelectionSection extends StatelessWidget {
  final String selectedNoteForPayment;
  final double total;
  final double totalForAll; // 🆕 SOURCE DE VÉRITÉ UNIQUE : Total pour "Tout payer" (toujours depuis getAllItemsOrganized)
  final double totalForMain; // 🆕 SOURCE DE VÉRITÉ UNIQUE : Total pour la note principale
  final double totalForPartial; // 🆕 SOURCE DE VÉRITÉ UNIQUE : Total pour le paiement partiel
  final OrderNote mainNote;
  final List<OrderNote> subNotes;
  final Function(String) getNoteColor;
  final Function(String) onNoteSelected;
  final Map<String, double> subNoteTotals; // 🆕 Totaux calculés depuis _getAllItemsOrganized()

  const NoteSelectionSection({
    super.key,
    required this.selectedNoteForPayment,
    required this.total,
    required this.totalForAll, // 🆕 SOURCE DE VÉRITÉ UNIQUE : Total pour "Tout payer"
    required this.totalForMain, // 🆕 SOURCE DE VÉRITÉ UNIQUE : Total pour la note principale
    required this.totalForPartial, // 🆕 SOURCE DE VÉRITÉ UNIQUE : Total pour le paiement partiel
    required this.mainNote,
    required this.subNotes,
    required this.getNoteColor,
    required this.onNoteSelected,
    required this.subNoteTotals, // 🆕 Totaux calculés depuis _getAllItemsOrganized()
  });

  Widget _buildCompactNoteButton(
    String noteId,
    String name,
    double total,
    IconData icon,
    Color color,
    bool isSelected, {
    bool isRecommended = false,
  }) {
    return Tooltip(
      message: noteId == 'all'
          ? 'Payer tous les articles de toutes les notes'
          : noteId == 'partial'
              ? 'Sélectionner des articles spécifiques à payer'
              : noteId == 'main'
                  ? 'Payer uniquement les articles de la note principale'
                  : 'Payer uniquement cette sous-note',
      child: InkWell(
        onTap: () => onNoteSelected(noteId),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // 🆕 Agrandi pour plus de visibilité
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 3 : 1, // Bordure plus épaisse si sélectionné
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icône avec check si sélectionné
              Stack(
                children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : color,
                size: 20, // 🆕 Agrandi pour plus de visibilité
              ),
                  if (isSelected)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_circle,
                          color: color,
                          size: 10,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8), // 🆕 Plus d'espace
              Text(
                name,
                style: TextStyle(
                  fontSize: 14, // 🆕 Agrandi pour plus de visibilité
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
              if (total > 0) ...[
                const SizedBox(width: 6), // 🆕 Plus d'espace
                Text(
                  '${total.toStringAsFixed(0)} TND',
                  style: TextStyle(
                    fontSize: 12, // 🆕 Agrandi pour plus de visibilité
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white70 : Colors.grey.shade600,
                  ),
                ),
              ],
              if (isRecommended && !isSelected) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Recommandé',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Détermine si "Note Principale" est redondante avec "Tout payer"
  /// (c'est-à-dire si mainNote contient exactement tous les articles)
  bool get _shouldHideMainNote {
    // Si pas de sous-notes, "Note Principale" = "Tout payer" (redondant)
    if (subNotes.isEmpty) return true;
    
    // Si toutes les sous-notes sont vides ou payées, "Note Principale" = "Tout payer"
    final hasActiveSubNotes = subNotes.any((note) => !note.paid && note.items.isNotEmpty);
    if (!hasActiveSubNotes) return true;
    
    // Si le total de mainNote = total global, alors c'est redondant
    // (tolérance de 0.01 TND pour les erreurs de virgule flottante)
    if ((mainNote.total - total).abs() < 0.01) return true;
    
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final shouldHideMainNote = _shouldHideMainNote;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🆕 Texte "Choisir ce qui doit être payé" retiré pour gagner de l'espace
          // Boutons compacts en ligne
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              // 1. Tout payer
              _buildCompactNoteButton(
                'all',
                'Tout payer',
                totalForAll, // 🆕 SOURCE DE VÉRITÉ UNIQUE : Utiliser totalForAll au lieu de total
                Icons.receipt_long,
                const Color(0xFF27AE60),
                selectedNoteForPayment == 'all',
                isRecommended: shouldHideMainNote && subNotes.isEmpty,
              ),
              
              // 2. Paiement partiel (articles sélectionnés)
              _buildCompactNoteButton(
                'partial',
                'Partiel',
                totalForPartial, // 🆕 SOURCE DE VÉRITÉ UNIQUE : Utiliser totalForPartial
                Icons.checklist,
                const Color(0xFF3498DB),
                selectedNoteForPayment == 'partial',
              ),
              
              // 3. Note principale (cachée si redondante)
              if (mainNote.items.isNotEmpty && !shouldHideMainNote)
                _buildCompactNoteButton(
                  'main',
                  'Note Principale',
                  totalForMain, // 🆕 SOURCE DE VÉRITÉ UNIQUE : Utiliser totalForMain au lieu de mainNote.total
                  Icons.note,
                  const Color(0xFF2196F3),
                  selectedNoteForPayment == 'main',
                ),
              
              // 4. Sous-notes (éviter les doublons)
              // 🆕 CORRECTION : Utiliser subNoteTotals au lieu de note.total
              ...subNotes
                  .fold<Map<String, OrderNote>>({}, (map, note) {
                    if (!map.containsKey(note.name) && !note.paid && note.items.isNotEmpty) {
                      map[note.name] = note;
                    }
                    return map;
                  })
                  .values
                  .map((note) => _buildCompactNoteButton(
                    note.id,
                    note.name,
                    subNoteTotals[note.id] ?? 0.0, // 🆕 Utiliser le total calculé depuis _getAllItemsOrganized()
                    Icons.person,
                    getNoteColor(note.id),
                    selectedNoteForPayment == note.id,
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

