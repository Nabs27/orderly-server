import 'package:flutter/material.dart';
import '../../../models/order_note.dart';

class TransferToNoteDialog extends StatelessWidget {
  final Map<int, int> selectedItems;
  final String activeNoteId;
  final int? activeOrderId;
  final OrderNote mainNote;
  final List<OrderNote> subNotes;
  final Color Function(String) getNoteColor;
  final Function(String, Map<int, int>, int?) onTransferToNote;
  final VoidCallback onCreateNewNote;

  const TransferToNoteDialog({
    super.key,
    required this.selectedItems,
    required this.activeNoteId,
    required this.activeOrderId,
    required this.mainNote,
    required this.subNotes,
    required this.getNoteColor,
    required this.onTransferToNote,
    required this.onCreateNewNote,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Transférer vers quelle note ?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.swap_horiz, color: Colors.orange.shade700, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Sélectionnez la note de destination pour ${selectedItems.length} articles',
                      style: TextStyle(color: Colors.orange.shade700, fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Note principale
            if (activeNoteId != 'main')
              Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Icon(Icons.note, color: Colors.blue, size: 28),
                  ),
                  title: const Text('Note Principale', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  subtitle: Text('${mainNote.items.length} articles - ${mainNote.total.toStringAsFixed(2)} TND', style: const TextStyle(fontSize: 14)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 20),
                  onTap: () {
                    Navigator.of(context).pop();
                    onTransferToNote(
                      'main',
                      selectedItems,
                      activeNoteId != 'main' ? activeOrderId : null,
                    );
                  },
                ),
              ),
            
            // Sous-notes existantes
            ...subNotes.where((note) => note.id != activeNoteId).map((note) => 
              Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: getNoteColor(note.id).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Icon(Icons.person, color: getNoteColor(note.id), size: 28),
                  ),
                  title: Text(note.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  subtitle: Text('${note.items.length} articles - ${note.total.toStringAsFixed(2)} TND', style: const TextStyle(fontSize: 14)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 20),
                  onTap: () {
                    Navigator.of(context).pop();
                    onTransferToNote(note.id, selectedItems, note.sourceOrderId);
                  },
                ),
              ),
            ),
            
            const Divider(thickness: 2),
            
            // Créer une nouvelle note
            Card(
              elevation: 3,
              margin: const EdgeInsets.symmetric(vertical: 6),
              color: Colors.green.shade50,
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Icon(Icons.add_circle, color: Colors.green, size: 28),
                ),
                title: const Text('Créer une nouvelle note', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                subtitle: const Text('Nouveau client/personne', style: TextStyle(fontSize: 14)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 20),
                onTap: () {
                  Navigator.of(context).pop();
                  onCreateNewNote();
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text('Annuler', style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }
}

