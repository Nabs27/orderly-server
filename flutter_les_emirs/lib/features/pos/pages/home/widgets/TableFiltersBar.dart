import 'package:flutter/material.dart';

// NOTE: Barre de filtres (placeholder). À brancher plus tard sur HomeState/HomeController.
class TableFiltersBar extends StatelessWidget {
  final String selectedServer;
  final Set<String> selectedStatuses;
  final void Function(String server) onServerChanged;
  final void Function(String status, bool selected) onStatusToggled;

  const TableFiltersBar({
    super.key,
    required this.selectedServer,
    required this.selectedStatuses,
    required this.onServerChanged,
    required this.onStatusToggled,
  });

  @override
  Widget build(BuildContext context) {
    final servers = const ['ALI', 'MOHAMED', 'FATIMA', 'ADMIN'];
    final statuses = const [
      ['libre', Colors.green],
      ['occupee', Colors.orange],
      ['reservee', Colors.blue],
    ];

    return Row(
      children: [
        DropdownButton<String>(
          value: servers.contains(selectedServer) ? selectedServer : servers.first,
          items: servers.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => v != null ? onServerChanged(v) : null,
        ),
        const SizedBox(width: 12),
        Wrap(
          spacing: 8,
          children: statuses.map((e) {
            final label = e[0] as String;
            final color = e[1] as MaterialColor;
            final selected = selectedStatuses.contains(label);
            return FilterChip(
              label: Text(label),
              selected: selected,
              onSelected: (val) => onStatusToggled(label, val),
              selectedColor: color.shade100,
              checkmarkColor: color,
            );
          }).toList(),
        ),
      ],
    );
  }
}


