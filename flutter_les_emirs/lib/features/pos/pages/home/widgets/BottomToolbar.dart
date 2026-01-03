import 'package:flutter/material.dart';

class BottomToolbar extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback onBills;
  final VoidCallback onServerReport;

  const BottomToolbar({
    super.key,
    required this.onSearch,
    required this.onBills,
    required this.onServerReport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onSearch,
              icon: const Icon(Icons.search),
              label: const Text('Rechercher Table'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(20),
                backgroundColor: const Color(0xFF3498DB),
                minimumSize: const Size(0, 60),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onBills,
              icon: const Icon(Icons.receipt_long),
              label: const Text('Factures du Jour'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(20),
                backgroundColor: const Color(0xFF27AE60),
                minimumSize: const Size(0, 60),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onServerReport,
              icon: const Icon(Icons.account_balance_wallet),
              label: const Text('Mes encaissements'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(20),
                backgroundColor: const Color(0xFF9B59B6),
                minimumSize: const Size(0, 60),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
