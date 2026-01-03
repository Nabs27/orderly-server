import 'package:flutter/services.dart';

/// Types de clavier virtuel disponibles
enum VirtualKeyboardType {
  /// Clavier alphabétique AZERTY (pour noms, textes)
  alpha,
  
  /// Num pad simple (0-9, pour numéros de table, couverts, PIN)
  numeric,
  
  /// Num pad avec décimales (0-9, virgule/point, pour montants)
  numericDecimal,
  
  /// Num pad pour téléphone (0-9, format téléphone)
  phone,
}

/// Extension pour détecter le type de clavier depuis un TextInputType
extension VirtualKeyboardTypeExtension on VirtualKeyboardType {
  /// Créer un VirtualKeyboardType depuis un TextInputType Flutter
  static VirtualKeyboardType fromTextInputType(TextInputType? inputType, {List<TextInputFormatter>? formatters}) {
    if (inputType == null) return VirtualKeyboardType.alpha;
    
    // Vérifier les formatters pour détecter digitsOnly
    if (formatters != null) {
      final hasDigitsOnly = formatters.any((f) => f.toString().contains('digitsOnly'));
      if (hasDigitsOnly) {
        // Si digitsOnly, c'est un num pad simple
        return VirtualKeyboardType.numeric;
      }
      
      // Vérifier si on accepte les décimales
      final hasDecimal = formatters.any((f) => 
        f.toString().contains('decimal') || 
        f.toString().contains(r'\.') ||
        f.toString().contains(',')
      );
      if (hasDecimal) {
        return VirtualKeyboardType.numericDecimal;
      }
    }
    
    // Détection basée sur TextInputType
    // Vérifier si c'est un numberWithOptions avec décimales
    final inputTypeStr = inputType.toString();
    if (inputTypeStr.contains('numberWithOptions') && inputTypeStr.contains('decimal: true')) {
      return VirtualKeyboardType.numericDecimal;
    }
    
    // Comparaison par index (plus fiable que switch avec TextInputType)
    if (inputType == TextInputType.number) {
      return VirtualKeyboardType.numeric;
    }
    
    if (inputType == TextInputType.phone) {
      return VirtualKeyboardType.phone;
    }
    
    // Pour tous les autres types (text, multiline, etc.), utiliser alpha
    return VirtualKeyboardType.alpha;
  }
}
