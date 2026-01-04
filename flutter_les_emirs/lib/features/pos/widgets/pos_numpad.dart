import 'package:flutter/material.dart';

class PosNumpad extends StatefulWidget {
  final Function(int) onNumberPressed;
  final VoidCallback onClear;
  final VoidCallback onCancel;
  final VoidCallback onNote;
  final VoidCallback onIngredient;
  final VoidCallback? onBack; // Bouton Retour (annulation)
  final Function(int)? onQuantityEntered; // 🆕 Callback pour saisie directe de quantité
  final bool enableQuantityMode; // 🆕 Activer le mode quantité

  const PosNumpad({
    super.key,
    required this.onNumberPressed,
    required this.onClear,
    required this.onCancel,
    required this.onNote,
    required this.onIngredient,
    this.onBack,
    this.onQuantityEntered, // 🆕 Optionnel
    this.enableQuantityMode = false, // 🆕 Désactivé par défaut
  });

  @override
  State<PosNumpad> createState() => _PosNumpadState();
}

class _PosNumpadState extends State<PosNumpad> {
  bool _quantityMode = false; // 🆕 Mode saisie quantité
  String _quantityBuffer = ''; // 🆕 Buffer pour la quantité saisie

  void _toggleQuantityMode() {
    setState(() {
      _quantityMode = !_quantityMode;
      _quantityBuffer = '';
    });
  }

  void _addToQuantityBuffer(int digit) {
    if (_quantityBuffer.length < 3) { // Max 3 chiffres
      setState(() {
        _quantityBuffer += digit.toString();
      });
    }
  }

  void _clearQuantityBuffer() {
    setState(() {
      _quantityBuffer = '';
    });
  }

  void _confirmQuantity() {
    if (_quantityBuffer.isNotEmpty && widget.onQuantityEntered != null) {
      final quantity = int.tryParse(_quantityBuffer);
      if (quantity != null && quantity > 0) {
        widget.onQuantityEntered!(quantity);
        setState(() {
          _quantityMode = false;
          _quantityBuffer = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 🆕 Affichage du buffer de quantité en mode quantité
        if (_quantityMode && widget.enableQuantityMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Quantité: ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blue),
                ),
                Text(
                  _quantityBuffer.isEmpty ? '___' : _quantityBuffer.padLeft(3, '_'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),

        GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: _quantityMode && widget.enableQuantityMode
              ? _buildQuantityModeButtons()
              : _buildNormalModeButtons(),
        ),
      ],
    );
  }

  List<Widget> _buildNormalModeButtons() {
    return [
      // Ligne 1: 7, 8, 9
      _buildNumButton('7', () => widget.onNumberPressed(7)),
      _buildNumButton('8', () => widget.onNumberPressed(8)),
      _buildNumButton('9', () => widget.onNumberPressed(9)),

      // Ligne 2: 4, 5, 6
      _buildNumButton('4', () => widget.onNumberPressed(4)),
      _buildNumButton('5', () => widget.onNumberPressed(5)),
      _buildNumButton('6', () => widget.onNumberPressed(6)),

      // Ligne 3: 1, 2, 3
      _buildNumButton('1', () => widget.onNumberPressed(1)),
      _buildNumButton('2', () => widget.onNumberPressed(2)),
      _buildNumButton('3', () => widget.onNumberPressed(3)),

      // Ligne 4: 0, 00, Mode Quantité (si activé)
      _buildNumButton('0', () => widget.onNumberPressed(0)),
      _buildNumButton('00', () => widget.onNumberPressed(0)),
      widget.enableQuantityMode
          ? _buildActionButton('Quantité', Icons.dialpad, Colors.purple.shade700, _toggleQuantityMode)
          : _buildActionButton('', Icons.circle, Colors.grey.shade700, () {}),

      // Ligne 5: Actions
      _buildActionButton('Annuler', Icons.close, Colors.red.shade700, widget.onCancel),
      _buildActionButton('Effacer', Icons.backspace, Colors.orange.shade700, widget.onClear),
      _buildActionButton('Retour', Icons.undo, Colors.blue.shade700, widget.onBack ?? () {}),
    ];
  }

  List<Widget> _buildQuantityModeButtons() {
    return [
      // Ligne 1: 7, 8, 9
      _buildNumButton('7', () => _addToQuantityBuffer(7)),
      _buildNumButton('8', () => _addToQuantityBuffer(8)),
      _buildNumButton('9', () => _addToQuantityBuffer(9)),

      // Ligne 2: 4, 5, 6
      _buildNumButton('4', () => _addToQuantityBuffer(4)),
      _buildNumButton('5', () => _addToQuantityBuffer(5)),
      _buildNumButton('6', () => _addToQuantityBuffer(6)),

      // Ligne 3: 1, 2, 3
      _buildNumButton('1', () => _addToQuantityBuffer(1)),
      _buildNumButton('2', () => _addToQuantityBuffer(2)),
      _buildNumButton('3', () => _addToQuantityBuffer(3)),

      // Ligne 4: 0, Effacer, Valider
      _buildNumButton('0', () => _addToQuantityBuffer(0)),
      _buildActionButton('Effacer', Icons.backspace, Colors.orange.shade700, _clearQuantityBuffer),
      _buildActionButton('OK', Icons.check, Colors.green.shade700, _confirmQuantity),

      // Ligne 5: Annuler, Retour mode normal, Vide
      _buildActionButton('Annuler', Icons.close, Colors.red.shade700, widget.onCancel),
      _buildActionButton('Normal', Icons.swap_horiz, Colors.blue.shade700, _toggleQuantityMode),
      _buildActionButton('', Icons.circle, Colors.grey.shade400, () {}),
    ];
  }

  Widget _buildNumButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF3498DB),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.all(0),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Widget _buildActionButton(String text, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.all(4),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: Colors.white),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}

