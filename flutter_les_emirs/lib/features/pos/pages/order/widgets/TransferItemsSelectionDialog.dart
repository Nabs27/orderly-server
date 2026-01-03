import 'package:flutter/material.dart';
import '../../../models/order_note.dart';

class TransferItemsSelectionDialog extends StatefulWidget {
  final OrderNote activeNote;
  final String activeNoteId;
  final Function(Map<int, int>) onItemsSelected;

  const TransferItemsSelectionDialog({
    super.key,
    required this.activeNote,
    required this.activeNoteId,
    required this.onItemsSelected,
  });

  @override
  State<TransferItemsSelectionDialog> createState() => _TransferItemsSelectionDialogState();
}

class _TransferItemsSelectionDialogState extends State<TransferItemsSelectionDialog> {
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
        title: const Text('Sélectionner les articles'),
        content: SizedBox(
          width: 500,
          height: 500,
          child: Column(
            children: [
              const Text('Sélectionnez les articles à transférer :'),
              const SizedBox(height: 16),
              
              Expanded(
                child: ListView.builder(
                  itemCount: widget.activeNote.items.length,
                  itemBuilder: (_, i) {
                    final item = widget.activeNote.items[i];
                    final selectedQty = selectedItems[i] ?? 0;
                    final isSelected = selectedQty > 0;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(item.name),
                        subtitle: Text('Prix: ${item.price.toStringAsFixed(2)} TND • Disponible: ${item.quantity}'),
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
                              icon: const Icon(Icons.remove),
                            ),
                            Container(
                              width: 40,
                              alignment: Alignment.center,
                              child: Text(
                                '$selectedQty/${item.quantity}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isSelected ? Colors.blue : Colors.grey,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: selectedQty < item.quantity ? () {
                                setDialogState(() {
                                  selectedItems[i] = selectedQty + 1;
                                });
                              } : null,
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                        selected: isSelected,
                        onTap: () {
                          setDialogState(() {
                            if (isSelected) {
                              selectedItems.remove(i);
                            } else {
                              selectedItems[i] = 1;
                            }
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
              
              if (selectedItems.isNotEmpty) ...[
                const Divider(),
                Text(
                  'Total sélectionné: ${selectedItems.entries.fold<double>(0.0, (sum, entry) {
                    final item = widget.activeNote.items[entry.key];
                    return sum + (item.price * entry.value);
                  }).toStringAsFixed(2)} TND',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: selectedItems.isEmpty ? null : () {
              Navigator.of(context).pop();
              widget.onItemsSelected(selectedItems);
            },
            child: const Text('Choisir table'),
          ),
        ],
      ),
    );
  }
}

