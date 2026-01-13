import 'package:flutter/material.dart';

/// Clavier alphabétique AZERTY avec support des accents
class AlphaKeyboard extends StatelessWidget {
  final Function(String) onKeyPressed;
  final VoidCallback? onBackspace;
  final VoidCallback? onSpace;
  final VoidCallback? onEnter;
  final bool showShift;
  final bool isShiftPressed;

  const AlphaKeyboard({
    super.key,
    required this.onKeyPressed,
    this.onBackspace,
    this.onSpace,
    this.onEnter,
    this.showShift = false,
    this.isShiftPressed = false,
  });

  /// Layout AZERTY standard
  static const List<List<String>> _azertyLayout = [
    ['a', 'z', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
    ['q', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'm'],
    ['w', 'x', 'c', 'v', 'b', 'n'],
  ];

  /// Accents disponibles pour les lettres courantes
  static const Map<String, List<String>> _accents = {
    'a': ['à', 'â', 'ä'],
    'e': ['é', 'è', 'ê', 'ë'],
    'i': ['î', 'ï'],
    'o': ['ô', 'ö'],
    'u': ['ù', 'û', 'ü'],
    'c': ['ç'],
  };

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth * 0.95; // Exploiter 95% de la largeur
    
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
            // Espacements entre lignes: 3 * 4px = 12px
            final totalSpacing = 16 + 12;
            final availableHeight = constraints.maxHeight - totalSpacing;
            final keyHeight = (availableHeight / 4).clamp(45.0, 70.0); // Augmenté pour meilleure ergonomie
            final fontSize = keyHeight * 0.45;
            
            return Builder(
              builder: (builderContext) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Première ligne
                  Flexible(child: _buildRow(_azertyLayout[0], keyHeight, fontSize, builderContext)),
                  const SizedBox(height: 4),
                  // Deuxième ligne
                  Flexible(child: _buildRow(_azertyLayout[1], keyHeight, fontSize, builderContext)),
                  const SizedBox(height: 4),
                  // Troisième ligne
                  Flexible(child: _buildRow(_azertyLayout[2], keyHeight, fontSize, builderContext)),
                  const SizedBox(height: 4),
                  // Ligne spéciale (espace, accents, backspace)
                  Flexible(child: _buildSpecialRow(keyHeight, fontSize)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRow(List<String> keys, double keyHeight, double fontSize, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((key) => Expanded(
        child: _buildKey(key, keyHeight, fontSize, context),
      )).toList(),
    );
  }

  Widget _buildKey(String key, double keyHeight, double fontSize, BuildContext context) {
    final displayKey = isShiftPressed ? key.toUpperCase() : key;
    final hasAccents = _accents.containsKey(key.toLowerCase());
    
    return GestureDetector(
      onTap: () => onKeyPressed(displayKey),
      onLongPress: hasAccents ? () => _showAccentMenu(context, key) : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
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
            displayKey,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialRow(double keyHeight, double fontSize) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Bouton Espace
        Expanded(
          flex: 3,
          child: _buildActionKey(
            'Espace',
            onSpace ?? () {},
            keyHeight,
            fontSize,
          ),
        ),
        const SizedBox(width: 4),
        // Bouton Tiret
        Expanded(
          child: _buildActionKey(
            '-',
            () => onKeyPressed('-'),
            keyHeight,
            fontSize,
          ),
        ),
        const SizedBox(width: 4),
        // Bouton Apostrophe
        Expanded(
          child: _buildActionKey(
            "'",
            () => onKeyPressed("'"),
            keyHeight,
            fontSize,
          ),
        ),
        const SizedBox(width: 4),
        // Bouton Entrée (si disponible)
        if (onEnter != null)
          Expanded(
            flex: 2,
            child: _buildActionKey(
              'Entrée',
              onEnter!,
              keyHeight,
              fontSize,
              icon: Icons.keyboard_return,
            ),
          ),
        if (onEnter != null) const SizedBox(width: 4),
        // Bouton Backspace
        Expanded(
          child: _buildActionKey(
            '⌫',
            onBackspace ?? () {},
            keyHeight,
            fontSize,
            icon: Icons.backspace_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildActionKey(
    String label,
    VoidCallback onTap,
    double keyHeight,
    double fontSize, {
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
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
          child: icon != null
              ? Icon(icon, size: fontSize * 1.2)
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: fontSize * 0.9,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                ),
        ),
      ),
    );
  }

  void _showAccentMenu(BuildContext context, String baseKey) {
    final accents = _accents[baseKey.toLowerCase()] ?? [];
    if (accents.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Touche de base
            _buildAccentKey(baseKey, context, () {
              Navigator.pop(context);
              onKeyPressed(baseKey);
            }),
            const SizedBox(width: 8),
            // Accents
            ...accents.map((accent) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _buildAccentKey(accent, context, () {
                    Navigator.pop(context);
                    onKeyPressed(accent);
                  }),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildAccentKey(String key, BuildContext context, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.12,
        height: MediaQuery.of(context).size.width * 0.12,
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade300, width: 2),
        ),
        child: Center(
          child: Text(
            key,
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width * 0.05,
              fontWeight: FontWeight.bold,
              color: Colors.blue.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}
