import 'package:flutter/material.dart';
import 'keyboard_types.dart';
import 'keyboards/alpha_keyboard.dart';
import 'keyboards/numeric_keyboard.dart';

/// Clavier virtuel intelligent qui s'adapte au type de saisie
class VirtualKeyboardWidget extends StatefulWidget {
  final VirtualKeyboardType type;
  final Function(String)? onKeyPressed;
  final VoidCallback? onBackspace;
  final VoidCallback? onSpace;
  final VoidCallback? onEnter;
  final bool showShift;
  final String decimalSeparator;

  const VirtualKeyboardWidget({
    super.key,
    required this.type,
    this.onKeyPressed,
    this.onBackspace,
    this.onSpace,
    this.onEnter,
    this.showShift = false,
    this.decimalSeparator = '.',
  });

  @override
  State<VirtualKeyboardWidget> createState() => _VirtualKeyboardWidgetState();
}

class _VirtualKeyboardWidgetState extends State<VirtualKeyboardWidget> {
  bool _isShiftPressed = false;

  @override
  Widget build(BuildContext context) {
    switch (widget.type) {
      case VirtualKeyboardType.alpha:
        return AlphaKeyboard(
          onKeyPressed: widget.onKeyPressed ?? (_) {},
          onBackspace: widget.onBackspace,
          onSpace: widget.onSpace,
          onEnter: widget.onEnter,
          showShift: widget.showShift,
          isShiftPressed: _isShiftPressed,
        );
      case VirtualKeyboardType.numeric:
        return NumericKeyboard(
          onKeyPressed: widget.onKeyPressed ?? (_) {},
          onBackspace: widget.onBackspace,
          showDecimal: false,
          decimalSeparator: widget.decimalSeparator,
        );
      case VirtualKeyboardType.numericDecimal:
        return NumericKeyboard(
          onKeyPressed: widget.onKeyPressed ?? (_) {},
          onBackspace: widget.onBackspace,
          showDecimal: true,
          decimalSeparator: widget.decimalSeparator,
        );
      case VirtualKeyboardType.phone:
        return NumericKeyboard(
          onKeyPressed: widget.onKeyPressed ?? (_) {},
          onBackspace: widget.onBackspace,
          showDecimal: false,
          decimalSeparator: widget.decimalSeparator,
        );
    }
  }
}
