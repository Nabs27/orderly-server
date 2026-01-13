import 'package:flutter/material.dart';

/// Num pad pour saisie numérique
class NumericKeyboard extends StatelessWidget {
  final Function(String) onKeyPressed;
  final VoidCallback? onBackspace;
  final VoidCallback? onClear;
  final bool showDecimal;
  final String decimalSeparator;

  const NumericKeyboard({
    super.key,
    required this.onKeyPressed,
    this.onBackspace,
    this.onClear,
    this.showDecimal = false,
    this.decimalSeparator = '.',
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth > 600 ? 500.0 : screenWidth * 0.75;
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Calculer la hauteur disponible pour les boutons
            // Padding: 8px haut + 8px bas = 16px
            // Espacements entre lignes: 3 * 4px = 12px (réduit)
            // Marges verticales des boutons: 4 lignes * 2 * 2px = 16px (réduit)
            final totalSpacing = 16 + 12 + 16; // 44px
            final availableHeight = constraints.maxHeight - totalSpacing;
            final keyHeight = (availableHeight / 4).clamp(30.0, 70.0); // Entre 30 et 70px
            final fontSize = keyHeight * 0.45; // Proportionnel à la hauteur
            
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ligne 1: 7, 8, 9
                Flexible(child: _buildRow(['7', '8', '9'], keyHeight, fontSize)),
                const SizedBox(height: 4),
                // Ligne 2: 4, 5, 6
                Flexible(child: _buildRow(['4', '5', '6'], keyHeight, fontSize)),
                const SizedBox(height: 4),
                // Ligne 3: 1, 2, 3
                Flexible(child: _buildRow(['1', '2', '3'], keyHeight, fontSize)),
                const SizedBox(height: 4),
                // Ligne 4: décimal, 0, backspace
                Flexible(child: _buildBottomRow(keyHeight, fontSize)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRow(List<String> keys, double keyHeight, double fontSize) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((key) => _buildKey(key, keyHeight, fontSize)).toList(),
    );
  }

  Widget _buildKey(String key, double keyHeight, double fontSize) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onKeyPressed(key),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          height: keyHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade400, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Text(
              key,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomRow(double keyHeight, double fontSize) {
    return Row(
      children: [
        // Bouton décimal (si activé) ou vide
        Expanded(
          child: showDecimal
              ? GestureDetector(
                  onTap: () => onKeyPressed(decimalSeparator),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    height: keyHeight,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade400, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        decimalSeparator,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ),
                )
              : const SizedBox(),
        ),
        // Bouton 0
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: () => onKeyPressed('0'),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              height: keyHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade400, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '0',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ),
          ),
        ),
        // Bouton Backspace
        Expanded(
          child: GestureDetector(
            onTap: onBackspace ?? () {},
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              height: keyHeight,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade400, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.backspace_outlined,
                  size: fontSize * 1.2,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
