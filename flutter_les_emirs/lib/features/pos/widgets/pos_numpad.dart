import 'package:flutter/material.dart';

class PosNumpad extends StatelessWidget {
  final Function(int) onNumberPressed;
  final VoidCallback onClear;
  final VoidCallback onCancel;
  final VoidCallback onNote;
  final VoidCallback onIngredient;
  final VoidCallback? onBack; // 🆕 Bouton Retour (annulation)

  const PosNumpad({
    super.key,
    required this.onNumberPressed,
    required this.onClear,
    required this.onCancel,
    required this.onNote,
    required this.onIngredient,
    this.onBack, // 🆕 Optionnel
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 6,
      mainAxisSpacing: 6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // Ligne 1: 7, 8, 9
        _buildNumButton('7', () => onNumberPressed(7)),
        _buildNumButton('8', () => onNumberPressed(8)),
        _buildNumButton('9', () => onNumberPressed(9)),
        
        // Ligne 2: 4, 5, 6
        _buildNumButton('4', () => onNumberPressed(4)),
        _buildNumButton('5', () => onNumberPressed(5)),
        _buildNumButton('6', () => onNumberPressed(6)),
        
        // Ligne 3: 1, 2, 3
        _buildNumButton('1', () => onNumberPressed(1)),
        _buildNumButton('2', () => onNumberPressed(2)),
        _buildNumButton('3', () => onNumberPressed(3)),
        
        // Ligne 4: 0, 00, .
        _buildNumButton('0', () => onNumberPressed(0)),
        _buildNumButton('00', () => onNumberPressed(0)), // Ou logique spécifique
        _buildActionButton('.', Icons.circle, Colors.grey.withValues(alpha: 0.7), () {}),
        
        // Ligne 5: Actions
        _buildActionButton('Annuler', Icons.close, Colors.red.withValues(alpha: 0.7), onCancel),
        _buildActionButton('Effacer', Icons.backspace, Colors.orange.withValues(alpha: 0.7), onClear),
        _buildActionButton('Retour', Icons.undo, Colors.blue.withValues(alpha: 0.7), onBack ?? () {}),
        
      ],
    );
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

