import 'package:flutter/material.dart';

class ReservationDialog extends StatelessWidget {
  final String tableNumber;
  const ReservationDialog({super.key, required this.tableNumber});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Table N° $tableNumber - Réservée'),
      content: const Text('Cette table est réservée. Voulez-vous la libérer ou l\'ouvrir ?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop('cancel'),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop('free'),
          child: const Text('Libérer'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop('open'),
          child: const Text('Ouvrir'),
        ),
      ],
    );
  }
}


