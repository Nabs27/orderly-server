import 'package:flutter/material.dart';

class TableOptionsDialog extends StatelessWidget {
  final String tableNumber;
  final String status;
  final int covers;
  final double? orderTotal;
  const TableOptionsDialog({
    super.key,
    required this.tableNumber,
    required this.status,
    required this.covers,
    this.orderTotal,
  });

  @override
  Widget build(BuildContext context) {
    final hasOrder = (orderTotal ?? 0) > 0;
    return AlertDialog(
      title: Text('Options - Table N° $tableNumber'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Statut: $status'),
          Text('Couverts: $covers'),
          if (hasOrder) Text('Total: ${orderTotal!.toStringAsFixed(2)} TND') else const Text('Aucune commande', style: TextStyle(color: Colors.grey)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop('cancel'),
          child: const Text('Annuler'),
        ),
        if (hasOrder)
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop('open'),
            icon: const Icon(Icons.receipt),
            label: const Text('Voir commande'),
          ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop('delete'),
          icon: const Icon(Icons.delete),
          label: const Text('Supprimer'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        ),
      ],
    );
  }
}


