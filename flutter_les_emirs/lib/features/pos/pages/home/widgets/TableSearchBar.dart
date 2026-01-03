import 'package:flutter/material.dart';

// NOTE: Barre de recherche (placeholder). À brancher plus tard sur HomeState/HomeController.
class TableSearchBar extends StatelessWidget {
  final String query;
  final ValueChanged<String> onChanged;
  const TableSearchBar({super.key, required this.query, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: TextEditingController(text: query),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Rechercher une table...',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
      ),
    );
  }
}


