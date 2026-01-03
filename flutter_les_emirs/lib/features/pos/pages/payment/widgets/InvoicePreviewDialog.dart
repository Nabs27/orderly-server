import 'package:flutter/material.dart';

class InvoicePreviewDialog extends StatelessWidget {
  final int tableNumber;
  final double finalTotal;
  final String selectedPaymentMode;
  final String? selectedNoteName;
  final String selectedNoteForPayment;
  final int covers;
  final String companyName;
  final String companyAddress;
  final String companyPhone;
  final String companyEmail;
  final String taxNumber;
  final Function(StateSetter) onInvoiceFormBuilt;
  final VoidCallback onGenerateInvoice;

  const InvoicePreviewDialog({
    super.key,
    required this.tableNumber,
    required this.finalTotal,
    required this.selectedPaymentMode,
    this.selectedNoteName,
    required this.selectedNoteForPayment,
    required this.covers,
    required this.companyName,
    required this.companyAddress,
    required this.companyPhone,
    required this.companyEmail,
    required this.taxNumber,
    required this.onInvoiceFormBuilt,
    required this.onGenerateInvoice,
  });

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Génération de Facture'),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Informations de base
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.table_restaurant, color: Colors.blue.shade700, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Table $tableNumber',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Total: ${finalTotal.toStringAsFixed(2)} TND'),
                      Text('Mode de paiement: $selectedPaymentMode'),
                      if (selectedNoteForPayment != 'all') ...[
                        Text('Note: ${selectedNoteName ?? "Sélectionnée"}'),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Nombre de couverts
                Row(
                  children: [
                    Icon(Icons.people, color: Colors.blue.shade700, size: 18),
                    const SizedBox(width: 8),
                    const Text('Nombre de couverts:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        if (covers > 1) setDialogState(() {});
                      },
                      icon: const Icon(Icons.remove_circle, size: 20),
                      iconSize: 20,
                    ),
                    Container(
                      width: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.shade300),
                      ),
                      child: Text(
                        '$covers',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setDialogState(() {}),
                      icon: const Icon(Icons.add_circle, size: 20),
                      iconSize: 20,
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Informations société
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.business, color: Colors.grey.shade700, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Informations société',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      onInvoiceFormBuilt(setDialogState),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              onGenerateInvoice();
            },
            icon: const Icon(Icons.receipt_long),
            label: const Text('Générer Facture'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9B59B6),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

