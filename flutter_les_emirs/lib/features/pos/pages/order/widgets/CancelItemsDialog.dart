import 'package:flutter/material.dart';

class CancelItemsDialog extends StatefulWidget {
  final List<Map<String, dynamic>> availableItems;
  final Map<int, int> selectedQuantities;
  final Function(int itemId, int quantity) onQuantityChanged;
  final Function(int itemId) onToggleItem;
  final Function(Map<String, dynamic>) onConfirm;
  final VoidCallback onCancel;

  const CancelItemsDialog({
    super.key,
    required this.availableItems,
    required this.selectedQuantities,
    required this.onQuantityChanged,
    required this.onToggleItem,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<CancelItemsDialog> createState() => _CancelItemsDialogState();
}

class _CancelItemsDialogState extends State<CancelItemsDialog> {
  late Map<int, int> _localSelectedQuantities;
  late Map<int, Map<String, dynamic>> _itemDetails; // État, raison, description, action pour chaque article

  // États possibles
  final List<String> _states = [
    'not_prepared',
    'prepared_not_served',
    'served_untouched',
    'served_touched',
  ];

  final Map<String, String> _stateLabels = {
    'not_prepared': 'Non préparé',
    'prepared_not_served': 'Préparé non servi',
    'served_untouched': 'Servi non entamé',
    'served_touched': 'Servi entamé',
  };

  // Raisons possibles
  final List<String> _reasons = [
    'non_conformity',
    'quality',
    'delay',
    'order_error',
    'client_dissatisfied',
    'other',
  ];

  final Map<String, String> _reasonLabels = {
    'non_conformity': 'Non-conformité',
    'quality': 'Qualité/Goût',
    'delay': 'Délai de préparation',
    'order_error': 'Erreur de commande',
    'client_dissatisfied': 'Client insatisfait',
    'other': 'Autre',
  };

  // Actions possibles selon l'état
  Map<String, List<String>> get _actionsByState => {
    'not_prepared': ['cancel'],
    'prepared_not_served': ['cancel'],
    'served_untouched': ['reassign', 'refund', 'replace', 'remake'],
    'served_touched': ['replace', 'remake', 'refund'],
  };

  final Map<String, String> _actionLabels = {
    'cancel': 'Annuler',
    'refund': 'Rembourser',
    'replace': 'Remplacer',
    'remake': 'Refaire',
    'reassign': 'Réaffecter',
  };

  @override
  void initState() {
    super.initState();
    _localSelectedQuantities = Map<int, int>.from(widget.selectedQuantities);
    _itemDetails = {};
    
    // Initialiser les détails pour chaque article sélectionné
    for (final itemId in _localSelectedQuantities.keys) {
      _itemDetails[itemId] = {
        'state': 'not_prepared',
        'reason': 'other',
        'description': '',
        'action': 'cancel',
      };
    }
  }

  void _updateItemDetail(int itemId, String key, dynamic value) {
    setState(() {
      if (!_itemDetails.containsKey(itemId)) {
        _itemDetails[itemId] = {
          'state': 'not_prepared',
          'reason': 'other',
          'description': '',
          'action': 'cancel',
        };
      }
      _itemDetails[itemId]![key] = value;
      
      // Mettre à jour l'action selon l'état
      if (key == 'state') {
        final state = value as String;
        final availableActions = _actionsByState[state] ?? ['cancel'];
        _itemDetails[itemId]!['action'] = availableActions.first;
      }
    });
  }

  void _handleConfirm() {
    if (_localSelectedQuantities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner au moins un article')),
      );
      return;
    }

    // Vérifier que tous les articles sélectionnés ont des détails complets
    for (final itemId in _localSelectedQuantities.keys) {
      final details = _itemDetails[itemId];
      if (details == null || details['state'] == null || details['reason'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez compléter les détails pour tous les articles sélectionnés')),
        );
        return;
      }
    }

    // Préparer les données de confirmation
    final cancellationData = {
      'items': _localSelectedQuantities.entries.map((entry) {
        final itemId = entry.key;
        final quantity = entry.value;
        final item = widget.availableItems.firstWhere(
          (item) => item['id'] == itemId,
          orElse: () => {'name': 'Inconnu', 'price': 0.0},
        );
        return {
          'id': itemId,
          'name': item['name'],
          'price': item['price'],
          'quantity': quantity,
          'orderId': item['orderId'], // 🆕 ID de la commande
          'noteId': item['noteId'], // 🆕 ID de la note
        };
      }).toList(),
      'cancellationDetails': {
        'state': _itemDetails[_localSelectedQuantities.keys.first]!['state'],
        'reason': _itemDetails[_localSelectedQuantities.keys.first]!['reason'],
        'description': _itemDetails[_localSelectedQuantities.keys.first]!['description'] ?? '',
        'action': _itemDetails[_localSelectedQuantities.keys.first]!['action'],
        // Pour la réaffectation, on demandera les détails après
        'reassignment': null,
      },
    };

    widget.onConfirm(cancellationData);
  }

  @override
  Widget build(BuildContext context) {
    final selectedItems = widget.availableItems.where(
      (item) => _localSelectedQuantities.containsKey(item['id'] as int),
    ).toList();

    return StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text(
          'Annuler des articles',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
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
                    Icon(Icons.warning, color: Colors.orange.withValues(alpha: 0.7), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Sélectionnez les articles à annuler et précisez leur état, la raison et l\'action à prendre.',
                        style: TextStyle(
                          color: Colors.orange.withValues(alpha: 0.7),
                          fontSize: 14,
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
                  itemCount: widget.availableItems.length,
                  itemBuilder: (_, i) {
                    final item = widget.availableItems[i];
                    final itemId = item['id'] as int;
                    final name = item['name'] as String;
                    final price = (item['price'] as num).toDouble();
                    final originalQty = item['quantity'] as int;
                    final isSelected = _localSelectedQuantities.containsKey(itemId);
                    final selectedQty = _localSelectedQuantities[itemId] ?? 0;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ExpansionTile(
                        leading: Checkbox(
                          value: isSelected,
                          onChanged: (checked) {
                            setDialogState(() {
                              if (checked == true) {
                                _localSelectedQuantities[itemId] = 1;
                                _itemDetails[itemId] = {
                                  'state': 'not_prepared',
                                  'reason': 'other',
                                  'description': '',
                                  'action': 'cancel',
                                };
                                widget.onToggleItem(itemId);
                              } else {
                                _localSelectedQuantities.remove(itemId);
                                _itemDetails.remove(itemId);
                                widget.onToggleItem(itemId);
                              }
                            });
                          },
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          '${price.toStringAsFixed(2)} TND × $originalQty',
                          style: TextStyle(
                            color: isSelected ? Colors.blue : Colors.grey,
                          ),
                        ),
                        trailing: isSelected
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    onPressed: selectedQty > 1
                                        ? () {
                                            setDialogState(() {
                                              _localSelectedQuantities[itemId] = selectedQty - 1;
                                              widget.onQuantityChanged(itemId, selectedQty - 1);
                                            });
                                          }
                                        : null,
                                  ),
                                  Text('$selectedQty'),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: selectedQty < originalQty
                                        ? () {
                                            setDialogState(() {
                                              _localSelectedQuantities[itemId] = selectedQty + 1;
                                              widget.onQuantityChanged(itemId, selectedQty + 1);
                                            });
                                          }
                                        : null,
                                  ),
                                ],
                              )
                            : null,
                        children: isSelected
                            ? [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // État du plat
                                      Text(
                                        'État du plat',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      DropdownButtonFormField<String>(
                                        value: _itemDetails[itemId]?['state'] ?? 'not_prepared',
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        items: _states.map((state) {
                                          return DropdownMenuItem(
                                            value: state,
                                            child: Text(_stateLabels[state] ?? state),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          if (value != null) {
                                            setDialogState(() {
                                              _updateItemDetail(itemId, 'state', value);
                                            });
                                          }
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      
                                      // Raison
                                      Text(
                                        'Raison',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      DropdownButtonFormField<String>(
                                        value: _itemDetails[itemId]?['reason'] ?? 'other',
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        items: _reasons.map((reason) {
                                          return DropdownMenuItem(
                                            value: reason,
                                            child: Text(_reasonLabels[reason] ?? reason),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          if (value != null) {
                                            setDialogState(() {
                                              _updateItemDetail(itemId, 'reason', value);
                                            });
                                          }
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      
                                      // Description
                                      Text(
                                        'Description (optionnel)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                          hintText: 'Détails supplémentaires...',
                                        ),
                                        maxLines: 2,
                                        onChanged: (value) {
                                          setDialogState(() {
                                            _updateItemDetail(itemId, 'description', value);
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      
                                      // Action
                                      Text(
                                        'Action à prendre',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Builder(
                                        builder: (context) {
                                          final currentState = _itemDetails[itemId]?['state'] ?? 'not_prepared';
                                          final availableActions = _actionsByState[currentState] ?? ['cancel'];
                                          final currentAction = _itemDetails[itemId]?['action'] ?? availableActions.first;
                                          
                                          return DropdownButtonFormField<String>(
                                            value: availableActions.contains(currentAction) ? currentAction : availableActions.first,
                                            decoration: const InputDecoration(
                                              border: OutlineInputBorder(),
                                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                            items: availableActions.map((action) {
                                              return DropdownMenuItem(
                                                value: action,
                                                child: Text(_actionLabels[action] ?? action),
                                              );
                                            }).toList(),
                                            onChanged: (value) {
                                              if (value != null) {
                                                setDialogState(() {
                                                  _updateItemDetail(itemId, 'action', value);
                                                });
                                              }
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ]
                            : [],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: widget.onCancel,
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: _handleConfirm,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirmer l\'annulation'),
          ),
        ],
      ),
    );
  }
}

