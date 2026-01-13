import 'package:flutter/material.dart';

class TableLegendBar extends StatelessWidget {
  const TableLegendBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        _LegendItem(label: 'Libre', color: Colors.green),
        SizedBox(width: 16),
        _LegendItem(label: 'Occupée', color: Colors.orange),
        SizedBox(width: 16),
        _LegendItem(label: 'Réservée', color: Colors.blue),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final MaterialColor color;
  const _LegendItem({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}


