import 'package:flutter/material.dart';

class TransferToTableDialog extends StatelessWidget {
  final double totalAmount;
  final int subNotesCount;
  final String currentTableNumber;
  final VoidCallback onTransferCompleteTable;
  final VoidCallback onTransferSpecificItems;

  const TransferToTableDialog({
    super.key,
    required this.totalAmount,
    required this.subNotesCount,
    required this.currentTableNumber,
    required this.onTransferCompleteTable,
    required this.onTransferSpecificItems,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Transfert vers une autre table', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Option 1: Transférer TOUTE la table
            Card(
              color: Colors.orange.shade50,
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(Icons.move_up, color: Colors.orange, size: 32),
                ),
                title: const Text('Transférer TOUTE la table', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                subtitle: Text('Note principale + $subNotesCount sous-note(s)\nTotal: ${totalAmount.toStringAsFixed(2)} TND', style: const TextStyle(fontSize: 14)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 24),
                onTap: () {
                  Navigator.of(context).pop();
                  onTransferCompleteTable();
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Option 2: Transférer des articles spécifiques
            Card(
              color: Colors.blue.shade50,
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(Icons.checklist, color: Colors.blue, size: 32),
                ),
                title: const Text('Transférer des articles spécifiques', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                subtitle: const Text('Sélectionner les articles à transférer', style: TextStyle(fontSize: 14)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 24),
                onTap: () {
                  Navigator.of(context).pop();
                  onTransferSpecificItems();
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
      ],
    );
  }
}

