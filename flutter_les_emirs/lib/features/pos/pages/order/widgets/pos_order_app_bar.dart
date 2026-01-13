import 'package:flutter/material.dart';
import '../../../models/order_note.dart';
import 'ServerSelectionDialog.dart';
import 'CoversDialog.dart';
import 'NotesDialog.dart';

class PosOrderAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String selectedServer;
  final String activeNoteId;
  final List<OrderNote> subNotes;
  final Color Function(String) getNoteColor;
  final VoidCallback onShowAddNoteDialog;
  final VoidCallback onShowServerSelectionDialog;
  final VoidCallback? onBack;
  final VoidCallback? onShowCoversDialog;
  final VoidCallback onShowNotesDialog;
  final Function(String) onNoteSelected;
  final VoidCallback? onConfirmClientOrder; // 🆕 Callback pour confirmer commande client
  final VoidCallback? onDeclineClientOrder; // 🆕 Callback pour décliner commande client
  final bool hasPendingClientOrder; // 🆕 Indique s'il y a une commande en attente

  const PosOrderAppBar({
    super.key,
    required this.selectedServer,
    required this.activeNoteId,
    required this.subNotes,
    required this.getNoteColor,
    required this.onShowAddNoteDialog,
    required this.onShowServerSelectionDialog,
    required this.onBack,
    required this.onShowCoversDialog,
    required this.onShowNotesDialog,
    required this.onNoteSelected,
    this.onConfirmClientOrder,
    this.onDeclineClientOrder,
    this.hasPendingClientOrder = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: selectedServer.isNotEmpty 
        ? Row(
          children: [
            // Badge note principale (plus grand)
            GestureDetector(
              onTap: () => onNoteSelected('main'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: activeNoteId == 'main' ? Colors.blue : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: activeNoteId == 'main' ? Colors.blue : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: Text(
                  'Note Principale',
                  style: TextStyle(
                    color: activeNoteId == 'main' ? Colors.white : Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // Badges sous-notes (plus grands)
            ...subNotes.fold<Map<String, OrderNote>>({}, (map, note) {
              if (!map.containsKey(note.name)) {
                map[note.name] = note;
              }
              return map;
            }).values.map((note) => GestureDetector(
              onTap: () => onNoteSelected(note.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: activeNoteId == note.id ? getNoteColor(note.id) : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: activeNoteId == note.id ? getNoteColor(note.id) : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: Text(
                  note.name,
                  style: TextStyle(
                    color: activeNoteId == note.id ? Colors.white : Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )).toList(),
            // Bouton ajouter note (plus grand)
            GestureDetector(
              onTap: onShowAddNoteDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.7), width: 2),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: Colors.white, size: 20),
                    SizedBox(width: 4),
                    Text(
                      'Ajouter',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        )
        : const Text('POS Caisse'),
      backgroundColor: const Color(0xFF2C3E50),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: selectedServer.isEmpty 
          ? onShowServerSelectionDialog
          : onBack ?? () => Navigator.of(context).pop(),
        tooltip: selectedServer.isEmpty ? 'Sélectionner serveur' : 'Retour au plan de salle',
      ),
      actions: [
        // 🆕 Boutons confirmation/déclinaison commande client (si en attente)
        if (hasPendingClientOrder && onConfirmClientOrder != null) ...[
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: OutlinedButton.icon(
              onPressed: onDeclineClientOrder,
              icon: const Icon(Icons.close, color: Colors.red),
              label: const Text('Décliner', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                foregroundColor: Colors.red,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: onConfirmClientOrder,
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: const Text('Confirmer', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.withValues(alpha: 0.7),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
        // Sélection serveur
        if (selectedServer.isEmpty)
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: onShowServerSelectionDialog,
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text('Sélectionner serveur', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          )
        else
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: onShowServerSelectionDialog,
              icon: const Icon(Icons.person, color: Colors.white),
              label: Text(selectedServer, style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        // Bouton Plan de salle (visible et grand)
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: ElevatedButton.icon(
            onPressed: selectedServer.isEmpty 
              ? onShowServerSelectionDialog
              : onBack ?? () => Navigator.of(context).pop(),
            icon: const Icon(Icons.table_restaurant, color: Colors.white),
            label: const Text('Plan de salle', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: selectedServer.isEmpty 
                ? Colors.orange
                : const Color(0xFF3498DB),
              foregroundColor: Colors.white,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.people),
          onPressed: onShowCoversDialog,
          tooltip: onShowCoversDialog == null ? 'Non autorisé' : 'Modifier couverts',
        ),
        IconButton(
          icon: const Icon(Icons.note),
          onPressed: onShowNotesDialog,
          tooltip: 'Ajouter note',
        ),
      ],
    );
  }
}

