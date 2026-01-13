import 'package:flutter/material.dart';

class CompleteTableTransferDialog extends StatefulWidget {
  final String currentTableNumber;
  final int subNotesCount;
  final double totalAmount;
  final int covers;
  final Future<List<Map<String, dynamic>>> Function() getAvailableTables;
  final Function(String targetTable, bool createTable, {int covers}) onTransfer;

  const CompleteTableTransferDialog({
    super.key,
    required this.currentTableNumber,
    required this.subNotesCount,
    required this.totalAmount,
    required this.covers,
    required this.getAvailableTables,
    required this.onTransfer,
  });

  @override
  State<CompleteTableTransferDialog> createState() => _CompleteTableTransferDialogState();
}

class _CompleteTableTransferDialogState extends State<CompleteTableTransferDialog> {
  final tableController = TextEditingController();
  final coversController = TextEditingController();
  bool createNewTable = false;
  List<Map<String, dynamic>> availableTables = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    coversController.text = widget.covers.toString();
    _loadTables();
  }

  @override
  void dispose() {
    tableController.dispose();
    coversController.dispose();
    super.dispose();
  }

  Future<void> _loadTables() async {
    final tables = await widget.getAvailableTables();
    setState(() {
      availableTables = tables;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text('Transférer TOUTE la table', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 500,
            height: 500,
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade300, width: 2),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange.withValues(alpha: 0.7), size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'Transfert complet de la Table ${widget.currentTableNumber}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Note Principale + ${widget.subNotesCount} sous-note(s)',
                              style: TextStyle(fontSize: 14, color: Colors.orange.withValues(alpha: 0.7)),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Total: ${widget.totalAmount.toStringAsFixed(2)} TND',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      const Text('Choisir destination:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      
                      // Tables existantes
                      if (availableTables.isNotEmpty)
                        Expanded(
                          child: ListView.builder(
                            itemCount: availableTables.length,
                            itemBuilder: (_, i) {
                              final table = availableTables[i];
                              final tableNumber = table['number'] as String;
                              
                              return Card(
                                child: ListTile(
                                  leading: const Icon(Icons.table_restaurant, color: Colors.blue),
                                  title: Text('Table $tableNumber', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  trailing: const Icon(Icons.arrow_forward),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    widget.onTransfer(tableNumber, false);
                                  },
                                ),
                              );
                            },
                          ),
                        )
                      else
                        const Text('Aucune table disponible', style: TextStyle(color: Colors.grey)),
                      
                      const Divider(),
                      
                      // Créer nouvelle table
                      Card(
                        color: Colors.green.shade50,
                        child: ListTile(
                          leading: const Icon(Icons.add_circle, color: Colors.green, size: 32),
                          title: const Text('Créer une NOUVELLE table', style: TextStyle(fontWeight: FontWeight.bold)),
                          onTap: () {
                            setDialogState(() => createNewTable = true);
                          },
                        ),
                      ),
                      
                      if (createNewTable) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: tableController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Numéro de la nouvelle table',
                            hintText: 'Ex: 5',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.table_restaurant),
                          ),
                          autofocus: true,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: coversController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de couverts',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.people),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler', style: TextStyle(fontSize: 16)),
            ),
            if (createNewTable)
              ElevatedButton(
                onPressed: () {
                  final targetTable = tableController.text.trim();
                  final newCovers = int.tryParse(coversController.text) ?? widget.covers;
                  if (targetTable.isNotEmpty && targetTable != widget.currentTableNumber) {
                    Navigator.of(context).pop();
                    widget.onTransfer(targetTable, true, covers: newCovers);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Transférer tout', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
          ],
        );
      },
    );
  }
}

