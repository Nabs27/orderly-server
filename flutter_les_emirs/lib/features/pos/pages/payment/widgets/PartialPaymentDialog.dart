import 'package:flutter/material.dart';

class PartialPaymentDialog extends StatefulWidget {
  final List<Map<String, dynamic>> organizedItems;
  final Map<int, int> selectedQuantities;
  final Function(int itemId, int quantity) onQuantityChanged;
  final Function(int itemId) onToggleItem;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const PartialPaymentDialog({
    super.key,
    required this.organizedItems,
    required this.selectedQuantities,
    required this.onQuantityChanged,
    required this.onToggleItem,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<PartialPaymentDialog> createState() => _PartialPaymentDialogState();
}

class _PartialPaymentDialogState extends State<PartialPaymentDialog> {
  // 🆕 Copie locale pour pouvoir mettre à jour l'état
  late Map<int, int> _localSelectedQuantities;

  @override
  void initState() {
    super.initState();
    // Initialiser avec les quantités passées
    _localSelectedQuantities = Map<int, int>.from(widget.selectedQuantities);
  }

  // 🆕 Calculer le total sélectionné
  double _calculateTotal() {
    return _localSelectedQuantities.entries.fold<double>(
      0.0,
      (sum, entry) {
        final itemId = entry.key;
        final quantity = entry.value;
        final item = widget.organizedItems.firstWhere(
          (item) => item['id'] == itemId,
          orElse: () => {'price': 0.0},
        );
        return sum + ((item['price'] as num).toDouble() * quantity);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSelected = _calculateTotal();

    return StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text(
          'Paiement partiel - Sélectionner les articles',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.7,
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
                        'Sélectionnez les articles que le client souhaite payer maintenant.\nArticles organisés par catégories : Boissons → Entrées → Plats → Desserts',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.organizedItems.length,
                  itemBuilder: (_, i) {
                    final item = widget.organizedItems[i];
                    final itemId = item['id'] as int;
                    final name = item['name'] as String;
                    final price = (item['price'] as num).toDouble();
                    final originalQty = item['quantity'] as int;
                    final selectedQty = _localSelectedQuantities[itemId] ?? 0;
                    final isSelected = selectedQty > 0;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(
                          name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Prix: ${price.toStringAsFixed(2)} TND • Disponible: $originalQty',
                          style: const TextStyle(fontSize: 14),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Boutons quantité - PLUS GRANDS POUR TACTILE
                            IconButton(
                              onPressed: selectedQty > 0
                                  ? () {
                                      setDialogState(() {
                                        final newQty = selectedQty - 1;
                                        if (newQty == 0) {
                                          _localSelectedQuantities.remove(itemId);
                                          widget.onToggleItem(itemId);
                                        } else {
                                          _localSelectedQuantities[itemId] = newQty;
                                          widget.onQuantityChanged(itemId, newQty);
                                        }
                                      });
                                    }
                                  : null,
                              icon: const Icon(Icons.remove_circle, size: 32),
                              iconSize: 32,
                              color: selectedQty > 0 ? Colors.red : Colors.grey,
                            ),
                            Container(
                              width: 70,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blue.shade100 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? Colors.blue : Colors.grey,
                                ),
                              ),
                              child: Text(
                                '$selectedQty/$originalQty',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isSelected ? Colors.blue.shade700 : Colors.grey.shade600,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: selectedQty < originalQty
                                  ? () {
                                      setDialogState(() {
                                        final newQty = selectedQty + 1;
                                        _localSelectedQuantities[itemId] = newQty;
                                        widget.onQuantityChanged(itemId, newQty);
                                      });
                                    }
                                  : null,
                              icon: const Icon(Icons.add_circle, size: 32),
                              iconSize: 32,
                              color: selectedQty < originalQty ? Colors.green : Colors.grey,
                            ),
                          ],
                        ),
                        selected: isSelected,
                        selectedTileColor: Colors.blue.shade50,
                        onTap: () {
                          setDialogState(() {
                            if (_localSelectedQuantities.containsKey(itemId)) {
                              _localSelectedQuantities.remove(itemId);
                              widget.onToggleItem(itemId);
                            } else {
                              _localSelectedQuantities[itemId] = originalQty;
                              widget.onToggleItem(itemId);
                            }
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
              if (_localSelectedQuantities.isNotEmpty) ...[
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
                      const Text(
                        'Total sélectionné:',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${totalSelected.toStringAsFixed(2)} TND',
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
            onPressed: widget.onCancel,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Annuler', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: _localSelectedQuantities.isEmpty
                ? null
                : () {
                    // Synchroniser les quantités sélectionnées avec le parent avant confirmation
                    widget.selectedQuantities.clear();
                    widget.selectedQuantities.addAll(_localSelectedQuantities);
                    widget.onConfirm();
                  },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              backgroundColor: Colors.blue,
            ),
            child: const Text('Confirmer', style: TextStyle(fontSize: 16, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

