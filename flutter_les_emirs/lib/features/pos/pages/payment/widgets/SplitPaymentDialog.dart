import 'package:flutter/material.dart';
import '../../../widgets/virtual_keyboard/keyboards/numeric_keyboard.dart';
import 'CreditClientDialog.dart';
import 'ChequeInfoDialog.dart';

class SplitPaymentDialog extends StatefulWidget {
  final double totalAmount;
  final Map<String, dynamic>? selectedClientForCredit;

  const SplitPaymentDialog({
    super.key,
    required this.totalAmount,
    this.selectedClientForCredit,
  });

  @override
  State<SplitPaymentDialog> createState() => _SplitPaymentDialogState();
}

class _SplitPaymentDialogState extends State<SplitPaymentDialog> {
  final Map<String, bool> _selectedModes = {};
  final Map<String, TextEditingController> _amountControllers = {};
  final Map<String, TextEditingController> _receivedControllers = {};
  final Map<String, FocusNode> _amountFocusNodes = {};
  final Map<String, FocusNode> _receivedFocusNodes = {};
  final Map<String, Map<String, dynamic>> _checkInfoData = {};
  final Map<String, dynamic> _creditClientForMode = {};
  final List<String> _availableModes = ['ESPECE', 'CARTE', 'CHEQUE', 'TPE', 'OFFRE', 'CREDIT'];
  
  TextEditingController? _activeController;

  @override
  void initState() {
    super.initState();
    for (final mode in _availableModes) {
      _amountControllers[mode] = TextEditingController();
      _receivedControllers[mode] = TextEditingController();
      _amountFocusNodes[mode] = FocusNode();
      _receivedFocusNodes[mode] = FocusNode();
      _selectedModes[mode] = false;

      // Listeners pour changer le contrôleur actif du clavier
      _amountFocusNodes[mode]!.addListener(() {
        if (_amountFocusNodes[mode]!.hasFocus) {
          setState(() => _activeController = _amountControllers[mode]);
        }
      });
      _receivedFocusNodes[mode]!.addListener(() {
        if (_receivedFocusNodes[mode]!.hasFocus) {
          setState(() => _activeController = _receivedControllers[mode]);
        }
      });
    }
  }

  @override
  void dispose() {
    for (var m in _availableModes) {
      _amountControllers[m]?.dispose();
      _receivedControllers[m]?.dispose();
      _amountFocusNodes[m]?.dispose();
      _receivedFocusNodes[m]?.dispose();
    }
    super.dispose();
  }

  double _getTotalEntered() {
    double total = 0;
    for (final mode in _availableModes) {
      if (_selectedModes[mode] == true) {
        final amount = double.tryParse(_amountControllers[mode]!.text.replaceAll(',', '.')) ?? 0;
        total += amount;
      }
    }
    return total;
  }

  double _getRemaining() {
    return widget.totalAmount - _getTotalEntered();
  }

  void _toggleMode(String mode) {
    setState(() {
      _selectedModes[mode] = !(_selectedModes[mode] ?? false);
      if (!_selectedModes[mode]!) {
        _amountControllers[mode]?.clear();
        _receivedControllers[mode]?.clear();
        if (mode == 'CREDIT') {
          _creditClientForMode.remove(mode);
        }
      } else if (mode == 'CREDIT') {
        _showCreditClientDialog(mode);
      }
    });
  }

  void _showCreditClientDialog(String mode) async {
    final client = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => CreditClientDialog(
        totalAmount: widget.totalAmount,
        onClientSelected: (client, amount) {
          Navigator.pop(context, client);
        },
      ),
    );

    if (client != null) {
      setState(() {
        _creditClientForMode[mode] = client;
      });
    } else {
      setState(() {
        _selectedModes[mode] = false;
      });
    }
  }

  void _distributeEqually() {
    final selectedCount = _selectedModes.values.where((v) => v == true).length;
    if (selectedCount == 0) return;

    final amountPerMode = widget.totalAmount / selectedCount;
    setState(() {
      for (final mode in _availableModes) {
        if (_selectedModes[mode] == true) {
          _amountControllers[mode]?.text = amountPerMode.toStringAsFixed(3);
          _receivedControllers[mode]?.text = amountPerMode.toStringAsFixed(3);
        }
      }
    });
  }

  void _validateAndConfirm() {
    final splitPayments = <String, double>{};
    final receivedAmounts = <String, double>{};
    final checkInfos = <String, Map<String, dynamic>>{};
    final creditClients = <String, int>{};

    double remainingToAllocate = widget.totalAmount;

    for (final mode in _availableModes) {
      if (_selectedModes[mode] == true) {
        double rawAmount = double.tryParse(_amountControllers[mode]!.text.replaceAll(',', '.')) ?? 0;
        double received = double.tryParse(_receivedControllers[mode]!.text.replaceAll(',', '.')) ?? rawAmount;

        if (rawAmount <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Le montant pour ${_getModeName(mode)} doit être supérieur à 0')),
          );
          return;
        }

        double amountForNote = rawAmount > remainingToAllocate ? remainingToAllocate : rawAmount;
        if (received < rawAmount) received = rawAmount;

        if (received < (amountForNote - 0.0001)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Le montant reçu pour ${_getModeName(mode)} est insuffisant')),
          );
          return;
        }

        splitPayments[mode] = amountForNote;
        receivedAmounts[mode] = received;
        remainingToAllocate -= amountForNote;

        if (mode == 'CHEQUE') {
          if (_checkInfoData[mode] == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Veuillez remplir les informations du chèque')),
            );
            return;
          }
          checkInfos[mode] = _checkInfoData[mode]!;
        }

        if (mode == 'CREDIT' && _creditClientForMode[mode] != null) {
          creditClients[mode] = _creditClientForMode[mode]['id'];
        }
      }
    }

    if (remainingToAllocate.abs() > 0.001) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veuillez couvrir la totalité de la note. Reste : ${remainingToAllocate.toStringAsFixed(3)} TND')),
      );
      return;
    }

    Navigator.pop(context, {
      'splitPayments': splitPayments,
      'receivedAmounts': receivedAmounts,
      'checkInfos': checkInfos,
      'creditClients': creditClients,
    });
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _getRemaining();
    final selectedCount = _selectedModes.values.where((v) => v == true).length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600, // Un peu plus large pour le clavier
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   const Text('Paiement Divisé', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                   IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(),
              const SizedBox(height: 12),
              
              // Sélection des modes
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableModes.map((mode) {
                  final isSelected = _selectedModes[mode] == true;
                  return FilterChip(
                    label: Text(_getModeName(mode), style: TextStyle(color: isSelected ? Colors.white : Colors.black87)),
                    selected: isSelected,
                    onSelected: (_) => _toggleMode(mode),
                    selectedColor: Colors.blue.shade700,
                    checkmarkColor: Colors.white,
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 20),
              
              // Champs de saisie
              ..._availableModes.where((m) => _selectedModes[m] == true).map((mode) {
                final client = _creditClientForMode[mode];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _activeController == _amountControllers[mode] || _activeController == _receivedControllers[mode] ? Colors.blue.shade300 : Colors.grey.shade300, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_getModeName(mode), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _amountControllers[mode],
                              focusNode: _amountFocusNodes[mode],
                              readOnly: true,
                              showCursor: true,
                              decoration: const InputDecoration(
                                labelText: 'Montant Note',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.receipt),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _receivedControllers[mode],
                              focusNode: _receivedFocusNodes[mode],
                              readOnly: true,
                              showCursor: true,
                              decoration: InputDecoration(
                                labelText: mode == 'ESPECE' ? 'Reçu Cash' : 'Montant Réel',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.payments_outlined),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (mode == 'CHEQUE') ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final result = await showDialog<Map<String, dynamic>>(
                              context: context,
                              builder: (context) => ChequeInfoDialog(
                                amount: double.tryParse(_amountControllers[mode]!.text) ?? 0,
                                initialData: _checkInfoData[mode],
                              ),
                            );
                            if (result != null) setState(() => _checkInfoData[mode] = result);
                          },
                          icon: const Icon(Icons.edit_note),
                          label: Text(_checkInfoData[mode] != null ? 'Infos Chèque OK' : 'Ajouter infos chèque'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.purple),
                        ),
                      ],
                      if (mode == 'CREDIT' && client != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('Client: ${client['name']}', style: const TextStyle(fontSize: 12, color: Colors.blue)),
                        ),
                    ],
                  ),
                );
              }),
              
              if (selectedCount > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextButton.icon(onPressed: _distributeEqually, icon: const Icon(Icons.balance), label: const Text('Répartir équitablement')),
                ),

              const Divider(),
              
              // Résumé et CLAVIER
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total à couvrir :', style: TextStyle(fontSize: 16)),
                    Text('${widget.totalAmount.toStringAsFixed(3)} TND', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              
              if (remaining != 0)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: remaining > 0 ? Colors.orange.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(remaining > 0 ? Icons.warning_amber : Icons.check_circle, color: remaining > 0 ? Colors.orange : Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        remaining > 0 ? 'Reste à payer : ${remaining.toStringAsFixed(3)} TND' : 'Excédent : ${remaining.abs().toStringAsFixed(3)} TND',
                        style: TextStyle(fontWeight: FontWeight.bold, color: remaining > 0 ? Colors.orange.shade800 : Colors.green.shade800),
                      ),
                    ],
                  ),
                ),

              if (_activeController != null) ...[
                const SizedBox(height: 20),
                NumericKeyboard(
                  showDecimal: true,
                  onKeyPressed: (key) {
                    if (key == '.' && _activeController!.text.contains('.')) return;
                    setState(() => _activeController!.text += key);
                  },
                  onBackspace: () {
                    final t = _activeController!.text;
                    if (t.isNotEmpty) setState(() => _activeController!.text = t.substring(0, t.length - 1));
                  },
                  onClear: () => setState(() => _activeController!.clear()),
                ),
              ],
              
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: remaining <= 0.01 && selectedCount >= 2 ? _validateAndConfirm : null,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
                    child: const Text('Valider le Paiement', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getModeName(String mode) {
    switch (mode) {
      case 'ESPECE': return 'ESPÈCES';
      case 'CARTE': return 'CARTE';
      case 'CHEQUE': return 'CHÈQUE';
      case 'TPE': return 'BANQUE TPE';
      case 'OFFRE': return 'OFFERT';
      case 'CREDIT': return 'CRÉDIT';
      default: return mode;
    }
  }
}
