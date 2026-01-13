import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'keyboard_types.dart';
import 'virtual_keyboard_widget.dart';

/// Helper pour créer un TextField avec clavier virtuel
/// 
/// Usage:
/// ```dart
/// VirtualKeyboardTextField(
///   controller: controller,
///   keyboardType: VirtualKeyboardType.alpha,
///   labelText: 'Nom',
/// )
/// ```
class VirtualKeyboardTextField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final VirtualKeyboardType keyboardType;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final InputDecoration? decoration;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final bool obscureText;
  final int? maxLength;
  final String? decimalSeparator;
  final TextStyle? style;
  final Widget? overlayWidget; // 🆕 Widget à afficher au-dessus du clavier
  final VoidCallback? onTap; // 🆕 Callback appelé quand on clique sur le champ

  const VirtualKeyboardTextField({
    super.key,
    this.controller,
    this.focusNode,
    required this.keyboardType,
    this.labelText,
    this.hintText,
    this.helperText,
    this.decoration,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.obscureText = false,
    this.maxLength,
    this.decimalSeparator,
    this.style,
    this.overlayWidget, // 🆕
    this.onTap, // 🆕
  });

  @override
  Widget build(BuildContext context) {
    return _VirtualKeyboardTextFieldStateful(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      decoration: decoration,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      autofocus: autofocus,
      obscureText: obscureText,
      maxLength: maxLength,
      decimalSeparator: decimalSeparator,
      style: style,
      overlayWidget: overlayWidget, // 🆕
      onTap: onTap, // 🆕
    );
  }
}

class _VirtualKeyboardTextFieldStateful extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final VirtualKeyboardType keyboardType;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final InputDecoration? decoration;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final bool obscureText;
  final int? maxLength;
  final String? decimalSeparator;
  final TextStyle? style;
  final Widget? overlayWidget; // 🆕 Widget à afficher au-dessus du clavier
  final VoidCallback? onTap; // 🆕 Callback appelé quand on clique sur le champ

  const _VirtualKeyboardTextFieldStateful({
    this.controller,
    this.focusNode,
    required this.keyboardType,
    this.labelText,
    this.hintText,
    this.helperText,
    this.decoration,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.obscureText = false,
    this.maxLength,
    this.decimalSeparator,
    this.style,
    this.overlayWidget, // 🆕
    this.onTap, // 🆕
  });

  @override
  State<_VirtualKeyboardTextFieldStateful> createState() => _VirtualKeyboardTextFieldStatefulState();
}

class _VirtualKeyboardTextFieldStatefulState extends State<_VirtualKeyboardTextFieldStateful> {
  late FocusNode _focusNode;
  OverlayEntry? _overlayEntry;
  OverlayEntry? _overlayWidgetEntry; // 🆕 Overlay pour le widget personnalisé
  final GlobalKey _textFieldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _hideKeyboard();
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      // Masquer le clavier système
      SystemChannels.textInput.invokeMethod('TextInput.hide');
      // 🆕 Attendre un peu avant d'afficher pour éviter les conflits
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _focusNode.hasFocus) {
          _showKeyboard();
        }
      });
    } else {
      // 🆕 Augmenter le délai pour éviter de cacher quand on clique sur le clavier
      // 🆕 Vérifier plusieurs fois avant de masquer pour éviter les faux positifs
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && _focusNode.hasFocus) {
          return; // Le focus a été restauré, ne pas masquer
        }
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && !_focusNode.hasFocus) {
            _hideKeyboard();
          }
        });
      });
    }
  }

  void _showKeyboard() {
    if (_overlayEntry != null) return;

    final overlay = Overlay.of(context);
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    
    // Calculer la hauteur du clavier selon le type
    double keyboardHeight;
    if (widget.keyboardType == VirtualKeyboardType.numeric || 
        widget.keyboardType == VirtualKeyboardType.numericDecimal ||
        widget.keyboardType == VirtualKeyboardType.phone) {
      // Numpad : 35% de la hauteur d'écran
      keyboardHeight = screenHeight * 0.35;
    } else {
      // Clavier alpha : 42% de la hauteur d'écran (augmenté de 20%)
      keyboardHeight = screenHeight * 0.42;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            // 🆕 Empêcher les taps sur le clavier de faire perdre le focus au TextField
            onTap: () {
              // 🆕 Maintenir explicitement le focus pour éviter qu'il disparaisse
              if (!_focusNode.hasFocus) {
                _focusNode.requestFocus();
              }
            },
            onTapDown: (_) {
              // 🆕 Empêcher la perte de focus lors d'un tapDown dans le vide
              if (!_focusNode.hasFocus) {
                _focusNode.requestFocus();
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: keyboardHeight,
              width: screenWidth,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: widget.keyboardType == VirtualKeyboardType.numeric || 
                           widget.keyboardType == VirtualKeyboardType.numericDecimal ||
                           widget.keyboardType == VirtualKeyboardType.phone
                      ? 500.0  // Numpad : 500px
                      : screenWidth * 0.95,  // Clavier alpha : 95% de la largeur
                  maxHeight: keyboardHeight - 16,
                ),
                child: VirtualKeyboardWidget(
              type: widget.keyboardType,
              decimalSeparator: widget.decimalSeparator ?? '.',
              onKeyPressed: (key) {
                final controller = widget.controller;
                if (controller == null || !mounted) {
                  return;
                }
                
                // 🆕 CRITIQUE: Récupérer la valeur AVANT de demander le focus
                // pour éviter que la sélection soit réinitialisée
                final currentValue = controller.value;
                final text = currentValue.text;
                final selection = currentValue.selection;
                
                // 🆕 S'assurer que le focus est maintenu, mais après avoir récupéré la sélection
                if (!_focusNode.hasFocus) {
                  _focusNode.requestFocus();
                }
                
                // 🆕 Si la sélection est invalide (tout sélectionné), utiliser la fin du texte
                final insertPosition = (selection.start == 0 && selection.end == text.length && text.isNotEmpty)
                    ? text.length
                    : selection.start.clamp(0, text.length);
                
                // 🆕 S'assurer que selection.end est valide
                final validEnd = selection.end.clamp(0, text.length);
                
                // Insérer le caractère à la position du curseur
                final newText = text.substring(0, insertPosition) +
                    key +
                    text.substring(validEnd);
                
                // Appliquer les formatters si présents
                String finalText = newText;
                int finalOffset = insertPosition + key.length;
                if (widget.inputFormatters != null && widget.inputFormatters!.isNotEmpty) {
                  TextEditingValue tempValue = TextEditingValue(
                    text: newText,
                    selection: TextSelection.collapsed(offset: insertPosition + key.length),
                  );
                  for (final formatter in widget.inputFormatters!) {
                    tempValue = formatter.formatEditUpdate(
                      currentValue,
                      tempValue,
                    );
                  }
                  finalText = tempValue.text;
                  finalOffset = tempValue.selection.start.clamp(0, finalText.length);
                }
                
                // 🆕 Calculer la position finale en s'assurant qu'elle est valide
                final finalPosition = finalOffset.clamp(0, finalText.length);
                
                // Créer la nouvelle valeur avec la sélection correcte
                final newValue = TextEditingValue(
                  text: finalText,
                  selection: TextSelection.collapsed(offset: finalPosition),
                );
                
                // Mettre à jour le controller immédiatement
                controller.value = newValue;
                
                // 🆕 Appeler onChanged explicitement pour déclencher la capitalisation
                widget.onChanged?.call(finalText);
                
                // 🆕 Attendre un frame pour que onChanged s'exécute, puis vérifier
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || controller != widget.controller) return;
                  
                  final actualText = controller.text;
                  final actualSelection = controller.selection;
                  
                  // 🆕 Si le texte a changé (par onChanged) ou la sélection est invalide, réajuster
                  if (actualText != finalText || actualSelection.end > actualText.length || actualSelection.start > actualText.length) {
                    final adjustedPosition = finalPosition.clamp(0, actualText.length);
                    controller.value = TextEditingValue(
                      text: actualText,
                      selection: TextSelection.collapsed(offset: adjustedPosition),
                    );
                    // 🆕 Rappeler onChanged après réajustement si le texte a changé
                    if (actualText != finalText) {
                      widget.onChanged?.call(actualText);
                    }
                  }
                });
                
                // Maintenir le focus après la mise à jour
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    if (!_focusNode.hasFocus) {
                      _focusNode.requestFocus();
                    }
                  }
                });
              },
              onBackspace: () {
                final controller = widget.controller;
                if (controller == null || !mounted) {
                  return;
                }
                
                // 🆕 CRITIQUE: Récupérer la valeur AVANT de demander le focus
                final currentValue = controller.value;
                final text = currentValue.text;
                final selection = currentValue.selection;
                
                // 🆕 S'assurer que le focus est maintenu
                if (!_focusNode.hasFocus) {
                  _focusNode.requestFocus();
                }
                
                // 🆕 Si tout est sélectionné (0-longueur), supprimer seulement le dernier caractère
                if (selection.start == 0 && selection.end == text.length && text.isNotEmpty) {
                  final newText = text.substring(0, text.length - 1);
                  final newValue = TextEditingValue(
                    text: newText,
                    selection: TextSelection.collapsed(offset: newText.length),
                  );
                  controller.value = newValue;
                  
                  // Vérifier après onChanged
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted || controller != widget.controller) return;
                    final actualText = controller.text;
                    final adjustedPosition = newText.length.clamp(0, actualText.length);
                    if (actualText != newText || controller.selection.end > actualText.length) {
                      controller.value = TextEditingValue(
                        text: actualText,
                        selection: TextSelection.collapsed(offset: adjustedPosition),
                      );
                    }
                    widget.onChanged?.call(actualText);
                  });
                  return;
                }
                
                if (selection.start > 0) {
                  // 🆕 S'assurer que selection.end est valide
                  final validEnd = selection.end.clamp(0, text.length);
                  
                  // Supprimer le caractère avant le curseur
                  final newText = text.substring(0, selection.start - 1) +
                      text.substring(validEnd);
                  
                  final newValue = TextEditingValue(
                    text: newText,
                    selection: TextSelection.collapsed(
                      offset: selection.start - 1,
                    ),
                  );
                  
                  // Mettre à jour le controller immédiatement
                  controller.value = newValue;
                  
                  // 🆕 Vérifier que le texte est toujours cohérent après la mise à jour
                  final actualText = controller.text;
                  
                  // 🆕 Si le texte a changé (par onChanged), réajuster la sélection
                  if (actualText != newText) {
                    final adjustedPosition = (selection.start - 1).clamp(0, actualText.length);
                    controller.value = TextEditingValue(
                      text: actualText,
                      selection: TextSelection.collapsed(offset: adjustedPosition),
                    );
                  }
                  
                  widget.onChanged?.call(actualText);
                  
                  // Maintenir le focus après la mise à jour
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      if (!_focusNode.hasFocus) {
                        _focusNode.requestFocus();
                      }
                    }
                  });
                }
              },
              onSpace: () {
                final controller = widget.controller;
                if (controller == null || !mounted) {
                  return;
                }
                
                // 🆕 CRITIQUE: Récupérer la valeur AVANT de demander le focus
                final currentValue = controller.value;
                final text = currentValue.text;
                final selection = currentValue.selection;
                
                // 🆕 S'assurer que le focus est maintenu
                if (!_focusNode.hasFocus) {
                  _focusNode.requestFocus();
                }
                
                // 🆕 Si la sélection est invalide (tout sélectionné), utiliser la fin du texte
                final insertPosition = (selection.start == 0 && selection.end == text.length && text.isNotEmpty)
                    ? text.length
                    : selection.start.clamp(0, text.length);
                
                // 🆕 S'assurer que selection.end est valide
                final validEnd = selection.end.clamp(0, text.length);
                
                // Insérer un espace
                final newText = text.substring(0, insertPosition) +
                    ' ' +
                    text.substring(validEnd);
                
                // 🆕 Calculer la position finale en s'assurant qu'elle est valide
                final finalPosition = (insertPosition + 1).clamp(0, newText.length);
                
                final newValue = TextEditingValue(
                  text: newText,
                  selection: TextSelection.collapsed(
                    offset: finalPosition,
                  ),
                );
                
                controller.value = newValue;
                
                // 🆕 Attendre un frame pour que onChanged s'exécute, puis vérifier
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || controller != widget.controller) return;
                  
                  final actualText = controller.text;
                  final actualSelection = controller.selection;
                  
                  // 🆕 Si le texte a changé (par onChanged) ou la sélection est invalide, réajuster
                  if (actualText != newText || actualSelection.end > actualText.length || actualSelection.start > actualText.length) {
                    final adjustedPosition = finalPosition.clamp(0, actualText.length);
                    controller.value = TextEditingValue(
                      text: actualText,
                      selection: TextSelection.collapsed(offset: adjustedPosition),
                    );
                  }
                });
                
                // Maintenir le focus après la mise à jour
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    if (!_focusNode.hasFocus) {
                      _focusNode.requestFocus();
                    }
                  }
                });
              },
              onEnter: widget.onSubmitted != null ? () {
                final controller = widget.controller;
                if (controller != null) {
                  widget.onSubmitted?.call(controller.text);
                }
              } : null,
                ),
              ),
            ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
    
    // 🆕 Afficher l'overlay widget si fourni
    if (widget.overlayWidget != null) {
      _overlayWidgetEntry = OverlayEntry(
        builder: (context) => Positioned(
          bottom: keyboardHeight + 20, // Au-dessus du clavier
          left: 20,
          right: 20,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Colors.transparent,
            child: widget.overlayWidget!,
          ),
        ),
      );
      overlay.insert(_overlayWidgetEntry!);
    }
  }

  void _hideKeyboard() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    
    // 🆕 Supprimer l'overlay widget
    _overlayWidgetEntry?.remove();
    _overlayWidgetEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: _textFieldKey,
      child: GestureDetector(
        // 🆕 Empêcher les clics sur le TextField de perdre le focus
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // 🆕 Appeler le callback onTap si fourni
          widget.onTap?.call();
          if (!_focusNode.hasFocus) {
            _focusNode.requestFocus();
          }
        },
        child: TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          style: widget.style,
          decoration: widget.decoration ??
              InputDecoration(
                labelText: widget.labelText,
                hintText: widget.hintText,
                helperText: widget.helperText,
              ),
          inputFormatters: widget.inputFormatters,
          textCapitalization: widget.textCapitalization,
          onChanged: (value) {
            widget.onChanged?.call(value);
          },
          onSubmitted: widget.onSubmitted,
          autofocus: widget.autofocus,
          obscureText: widget.obscureText,
          maxLength: widget.maxLength,
          // Désactiver le clavier système
          keyboardType: TextInputType.none,
          showCursor: true,
          // 🆕 Empêcher la perte de focus automatique
          enableInteractiveSelection: true,
          // 🆕 Sélectionner tout le texte au focus pour permettre remplacement immédiat (comme les POS)
          selectAllOnFocus: true,
        ),
      ),
    );
  }
}
