import 'package:flutter/material.dart';
import '../../../models/order_note.dart';

class TransferDialog extends StatefulWidget {
  final OrderNote activeNote;
  final String activeNoteId;
  final Function(Map<int, int> selectedItems) onTransfer;

  const TransferDialog({
    super.key,
    required this.activeNote,
    required this.activeNoteId,
    required this.onTransfer,
  });

  @override
  State<TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<TransferDialog> {
  final selectedItems = <int, int>{};

  @override
  void initState() {
    super.initState();
    // Si c'est une sous-note, tout sélectionner par défaut
    if (widget.activeNoteId != 'main') {
      for (int i = 0; i < widget.activeNote.items.length; i++) {
        selectedItems[i] = widget.activeNote.items[i].quantity;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text('Transfert de ${widget.activeNote.name}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 600,
          height: 500,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade700, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.activeNoteId != 'main' 
                          ? 'Transfert complet de ${widget.activeNote.name} vers une autre table. Tous les articles sont sélectionnés.'
                          : 'Sélectionnez les articles à transférer vers une nouvelle note.',
                        style: TextStyle(color: Colors.blue.shade700, fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.activeNote.items.length,
                  itemBuilder: (_, i) {
                    final item = widget.activeNote.items[i];
                    final selectedQty = selectedItems[i] ?? 0;
                    final isSelected = selectedQty > 0;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(
                          item.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Prix: ${item.price.toStringAsFixed(2)} TND • Disponible: ${item.quantity}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: selectedQty > 0 ? () {
                                setDialogState(() {
                                  selectedItems[i] = selectedQty - 1;
                                  if (selectedItems[i] == 0) {
                                    selectedItems.remove(i);
                                  }
                                });
                              } : null,
                              icon: const Icon(Icons.remove_circle, size: 32),
                              iconSize: 32,
                              color: selectedQty > 0 ? Colors.red : Colors.grey,
                            ),
                            Container(
                              width: 60,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blue.shade100 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isSelected ? Colors.blue : Colors.grey),
                              ),
                              child: Text(
                                '$selectedQty/${item.quantity}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isSelected ? Colors.blue.shade700 : Colors.grey.shade600,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: selectedQty < item.quantity ? () {
                                setDialogState(() {
                                  selectedItems[i] = selectedQty + 1;
                                });
                              } : null,
                              icon: const Icon(Icons.add_circle, size: 32),
                              iconSize: 32,
                              color: selectedQty < item.quantity ? Colors.green : Colors.grey,
                            ),
                          ],
                        ),
                        selected: isSelected,
                        selectedTileColor: Colors.blue.shade50,
                        onTap: () {
                          setDialogState(() {
                            if (isSelected) {
                              selectedItems.remove(i);
                            } else {
                              selectedItems[i] = item.quantity;
                            }
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
              if (selectedItems.isNotEmpty) ...[
                const Divider(thickness: 2),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total sélectionné:',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${selectedItems.entries.fold<double>(0.0, (sum, entry) {
                          final item = widget.activeNote.items[entry.key];
                          return sum + (item.price * entry.value);
                        }).toStringAsFixed(2)} TND',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
          ElevatedButton(
            onPressed: selectedItems.isEmpty ? null : () {
              Navigator.of(context).pop();
              widget.onTransfer(selectedItems);
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              backgroundColor: Colors.blue,
            ),
            child: const Text('Transférer', style: TextStyle(fontSize: 16, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

