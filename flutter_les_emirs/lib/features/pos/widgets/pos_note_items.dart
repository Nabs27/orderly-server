import 'package:flutter/material.dart';
import '../models/order_note.dart';

class PosNoteItems extends StatelessWidget {
  final OrderNote note;
  final Set<int> newlyAddedItems;
  final Function(int, int) onQuantityChanged;
  final Function(int) onItemRemoved;

  const PosNoteItems({
    super.key,
    required this.note,
    required this.newlyAddedItems,
    required this.onQuantityChanged,
    required this.onItemRemoved,
  });

  @override
  Widget build(BuildContext context) {
    if (note.items.isEmpty) {
      return const Center(
        child: Text(
          'Aucun article dans cette note',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: note.items.length,
      itemBuilder: (context, index) {
        final item = note.items[index];
        final isNewlyAdded = newlyAddedItems.contains(item.id);
        
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isNewlyAdded 
                ? Colors.green.shade50 
                : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isNewlyAdded 
                  ? Colors.green.shade300 
                  : Colors.grey.shade300,
              width: isNewlyAdded ? 2 : 1,
            ),
            boxShadow: isNewlyAdded ? [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isNewlyAdded 
                    ? Colors.green.shade100 
                    : Colors.blue.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isNewlyAdded ? Icons.add_circle : Icons.restaurant,
                color: isNewlyAdded 
                    ? Colors.green.withValues(alpha: 0.7) 
                    : Colors.blue.withValues(alpha: 0.7),
                size: 20,
              ),
            ),
            title: Text(
              item.name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isNewlyAdded 
                    ? Colors.green.shade800 
                    : Colors.black87,
              ),
            ),
            subtitle: Text(
              '${item.price.toStringAsFixed(2)} TND',
              style: TextStyle(
                fontSize: 14,
                color: isNewlyAdded 
                    ? Colors.green.shade600 
                    : Colors.grey.shade600,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bouton diminuer quantité
                IconButton(
                  onPressed: item.quantity > 1 
                      ? () => onQuantityChanged(index, item.quantity - 1)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  color: Colors.red.shade600,
                ),
                
                // Quantité
                Container(
                  width: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isNewlyAdded 
                        ? Colors.green.shade100 
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isNewlyAdded 
                          ? Colors.green.shade300 
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    '${item.quantity}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isNewlyAdded 
                          ? Colors.green.withValues(alpha: 0.7) 
                          : Colors.black87,
                    ),
                  ),
                ),
                
                // Bouton augmenter quantité
                IconButton(
                  onPressed: () => onQuantityChanged(index, item.quantity + 1),
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  color: Colors.green.shade600,
                ),
                
                // Bouton supprimer
                IconButton(
                  onPressed: () => onItemRemoved(index),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: Colors.red.shade600,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
