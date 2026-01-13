import 'package:flutter/material.dart';
import '../../../widgets/virtual_keyboard/virtual_keyboard.dart';

class AddNoteDialog extends StatefulWidget {
  final Function(String name, int covers) onCreateNote;

  const AddNoteDialog({
    super.key,
    required this.onCreateNote,
  });

  @override
  State<AddNoteDialog> createState() => _AddNoteDialogState();
}

class _AddNoteDialogState extends State<AddNoteDialog> {
  final nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  int noteCovers = 1;

  String _toTitleCase(String input) {
    if (input.isEmpty) return input;
    
    print('[AddNoteDialog] 🔤 _toTitleCase input: "$input"');
    
    // 🆕 Préserver les espaces en fin de chaîne
    final trailingSpacesMatch = RegExp(r'\s+$').firstMatch(input);
    final trailingSpaces = trailingSpacesMatch != null ? trailingSpacesMatch.group(0)! : '';
    final trimmedInput = input.trimRight();
    
    if (trimmedInput.isEmpty) return input; // Si tout était des espaces, retourner l'original
    
    // Normaliser espaces (mais pas les espaces en fin)
    final normalized = trimmedInput.replaceAll(RegExp(r'\s+'), ' ');
    
    // Gérer espaces, tirets et apostrophes
    final buffer = StringBuffer();
    bool upperNext = true; // 🆕 Toujours mettre en majuscule la première lettre
    for (int i = 0; i < normalized.length; i++) {
      final ch = normalized[i];
      if (upperNext && RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿ]').hasMatch(ch)) {
        buffer.write(ch.toUpperCase());
        upperNext = false;
      } else {
        buffer.write(ch.toLowerCase());
      }
      if (ch == ' ' || ch == '-' || ch == '\'') {
        upperNext = true; // 🆕 Mettre en majuscule après un espace, tiret ou apostrophe
      }
    }
    
    // 🆕 Réajouter les espaces en fin
    final result = buffer.toString() + trailingSpaces;
    print('[AddNoteDialog] 🔤 _toTitleCase output: "$result"');
    return result;
  }

  @override
  void dispose() {
    nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
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
                  'Créer une note séparée',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                // Champ nom
                VirtualKeyboardTextField(
                  controller: nameController,
                  focusNode: _nameFocusNode,
                  keyboardType: VirtualKeyboardType.alpha,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    labelText: 'Prénom / Nom',
                    labelStyle: TextStyle(fontSize: 18),
                    hintText: 'Ex: Nabil Ben Ali',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person, size: 28),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  ),
                  textCapitalization: TextCapitalization.words,
                  autofocus: true,
                  onChanged: (value) {
                    // Capitalisation progressive pour l'expérience utilisateur
                    final titled = _toTitleCase(value);
                    if (titled != value) {
                      final sel = nameController.selection;
                      // 🆕 S'assurer que la sélection est valide après la modification
                      final validStart = sel.start.clamp(0, titled.length);
                      final validEnd = sel.end.clamp(0, titled.length);
                      nameController.value = TextEditingValue(
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
                const Text(
                  'Nombre de couverts:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: IconButton(
                        onPressed: noteCovers > 1 ? () => setState(() => noteCovers--) : null,
                        icon: const Icon(Icons.remove_circle, size: 40),
                        color: Colors.red.withValues(alpha: 0.7),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey, width: 2),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade50,
                      ),
                      child: Text(
                        '$noteCovers',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: IconButton(
                        onPressed: () => setState(() => noteCovers++),
                        icon: const Icon(Icons.add_circle, size: 40),
                        color: Colors.green.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 56,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                        ),
                        child: const Text('Annuler', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          final raw = nameController.text.trim();
                          final name = _toTitleCase(raw);
                          if (name.isNotEmpty) {
                            Navigator.of(context).pop();
                            widget.onCreateNote(name, noteCovers);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          backgroundColor: Colors.green,
                        ),
                        child: const Text(
                          'Créer',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
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

