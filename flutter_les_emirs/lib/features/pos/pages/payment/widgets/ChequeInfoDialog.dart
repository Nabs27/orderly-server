import 'package:flutter/material.dart';
import '../../../widgets/virtual_keyboard/virtual_keyboard.dart';
import '../../../widgets/virtual_keyboard/keyboards/numeric_keyboard.dart';

class ChequeInfoDialog extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final double amount;

  const ChequeInfoDialog({
    super.key,
    this.initialData,
    required this.amount,
  });

  @override
  State<ChequeInfoDialog> createState() => _ChequeInfoDialogState();
}

class _ChequeInfoDialogState extends State<ChequeInfoDialog> {
  late TextEditingController _nameController;
  late TextEditingController _numberController;
  String? _selectedBank;
  TextEditingController? _activeController;
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _numberFocusNode = FocusNode();

  final List<String> _tunisianBanks = [
    'BIAT', 'BNA', 'ATTIJARI', 'STB', 'BH BANK', 'UIB', 'AMEN', 'BT', 'ATB', 'BTE', 'ZITOUNA', 'AL BARAKA', 'POSTE', 'AUTRE'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialData?['name'] ?? '');
    _numberController = TextEditingController(text: widget.initialData?['number'] ?? '');
    _selectedBank = widget.initialData?['bank'];
    
    _numberFocusNode.addListener(() {
      if (_numberFocusNode.hasFocus) setState(() => _activeController = _numberController);
    });
    // Pour le nom, on laisse l'overlay s'il veut, mais on peut aussi piloter ici
    _nameFocusNode.addListener(() {
      if (_nameFocusNode.hasFocus) setState(() => _activeController = null); // On laisse l'overlay pour alpha
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _nameFocusNode.dispose();
    _numberFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance, color: Colors.purple.shade700),
                  const SizedBox(width: 12),
                  const Text('INFOS CHÈQUE', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('${widget.amount.toStringAsFixed(3)} TND', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple.shade700)),
                ],
              ),
              const Divider(height: 32),
              
              // Nom
              VirtualKeyboardTextField(
                controller: _nameController,
                focusNode: _nameFocusNode,
                keyboardType: VirtualKeyboardType.alpha,
                decoration: const InputDecoration(
                  labelText: 'Nom & Prénom du tireur',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              // Numéro
              TextField(
                controller: _numberController,
                focusNode: _numberFocusNode,
                readOnly: true,
                showCursor: true,
                decoration: const InputDecoration(
                  labelText: 'Numéro de chèque',
                  prefixIcon: Icon(Icons.pin),
                  border: OutlineInputBorder(),
                ),
              ),
              
              if (_activeController == _numberController) ...[
                const SizedBox(height: 12),
                NumericKeyboard(
                  showDecimal: false,
                  onKeyPressed: (key) => setState(() => _numberController.text += key),
                  onBackspace: () {
                    final t = _numberController.text;
                    if (t.isNotEmpty) setState(() => _numberController.text = t.substring(0, t.length - 1));
                  },
                  onClear: () => setState(() => _numberController.clear()),
                ),
              ],
              
              const SizedBox(height: 20),
              const Text('Sélectionner la Banque :', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              
              // Grille de banques tactile
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tunisianBanks.map((bank) {
                  final isSelected = _selectedBank == bank;
                  return InkWell(
                    onTap: () => setState(() => _selectedBank = bank),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.purple.shade700 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isSelected ? Colors.purple.shade700 : Colors.grey.shade300),
                      ),
                      child: Text(
                        bank,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER')),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (_nameController.text.isEmpty || _numberController.text.isEmpty || _selectedBank == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez remplir tous les champs')));
                        return;
                      }
                      Navigator.pop(context, {
                        'name': _nameController.text,
                        'number': _numberController.text,
                        'bank': _selectedBank,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
                    ),
                    child: const Text('VALIDER'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
