import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../widgets/virtual_keyboard/virtual_keyboard.dart';

/// Dialog pour saisir le nom du client (prénom et nom) pour justifier une remise
class DiscountClientNameDialog extends StatefulWidget {
  final String? initialClientName; // Nom initial (ex: nom de la sous-note)

  const DiscountClientNameDialog({
    super.key,
    this.initialClientName,
  });

  @override
  State<DiscountClientNameDialog> createState() => _DiscountClientNameDialogState();
}

class _DiscountClientNameDialogState extends State<DiscountClientNameDialog> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // 🆕 Préremplir avec le nom initial si fourni
    if (widget.initialClientName != null && widget.initialClientName!.isNotEmpty) {
      _nameController.text = widget.initialClientName!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  /// Capitalise la première lettre de chaque mot (même logique que AddNoteDialog)
  String _toTitleCase(String input) {
    if (input.isEmpty) return input;
    
    // Préserver les espaces en fin de chaîne
    final trailingSpacesMatch = RegExp(r'\s+$').firstMatch(input);
    final trailingSpaces = trailingSpacesMatch != null ? trailingSpacesMatch.group(0)! : '';
    final trimmedInput = input.trimRight();
    
    if (trimmedInput.isEmpty) return input;
    
    // Normaliser espaces (mais pas les espaces en fin)
    final normalized = trimmedInput.replaceAll(RegExp(r'\s+'), ' ');
    
    // Gérer espaces, tirets et apostrophes
    final buffer = StringBuffer();
    bool upperNext = true;
    for (int i = 0; i < normalized.length; i++) {
      final ch = normalized[i];
      if (upperNext && RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿ]').hasMatch(ch)) {
        buffer.write(ch.toUpperCase());
        upperNext = false;
      } else {
        buffer.write(ch.toLowerCase());
      }
      if (ch == ' ' || ch == '-' || ch == '\'') {
        upperNext = true;
      }
    }
    
    // Réajouter les espaces en fin
    return buffer.toString() + trailingSpaces;
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Material(
          type: MaterialType.card,
          borderRadius: BorderRadius.circular(8),
          elevation: 8,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Titre
                const Text(
                  'Nom du client',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                // Champ nom
                VirtualKeyboardTextField(
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  keyboardType: VirtualKeyboardType.alpha,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(
                    labelText: 'Prénom / Nom',
                    labelStyle: TextStyle(fontSize: 16),
                    hintText: 'Ex: Mohamed Ben Ali',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person, size: 24),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  ),
                  textCapitalization: TextCapitalization.words,
                  autofocus: true,
                  onChanged: (value) {
                    // Capitalisation progressive pour l'expérience utilisateur
                    final titled = _toTitleCase(value);
                    if (titled != value) {
                      final sel = _nameController.selection;
                      final validStart = sel.start.clamp(0, titled.length);
                      final validEnd = sel.end.clamp(0, titled.length);
                      _nameController.value = TextEditingValue(
                        text: titled,
                        selection: TextSelection(
                          baseOffset: validStart,
                          extentOffset: validEnd,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 24),
                // Boutons d'action
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final raw = _nameController.text.trim();
                        final name = _toTitleCase(raw);
                        Navigator.of(context).pop(name.isEmpty ? null : name);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.withValues(alpha: 0.7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Valider'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
