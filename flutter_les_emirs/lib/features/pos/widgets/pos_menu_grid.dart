import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PosMenuGrid extends StatefulWidget {
  final Map<String, dynamic> menu;
  final Function(Map<String, dynamic>) onItemSelected;

  const PosMenuGrid({
    super.key,
    required this.menu,
    required this.onItemSelected,
  });

  @override
  State<PosMenuGrid> createState() => _PosMenuGridState();
}

class _PosMenuGridState extends State<PosMenuGrid> {
  // État de navigation
  Map<String, List<Map<String, dynamic>>> groupToCategories = {};
  String? activeGroup; // 'drinks' | 'spirits' | 'entrees' | 'plats' | 'desserts'
  String? activeType; // ex: 'Entrée froide', 'Boisson froide', '__VIN__' pour Vin regroupé
  String? activeWineSubType; // 'Vin blanc' | 'Vin rosé' | 'Vin rouge' | 'Vin français'
  int? _selectedItemId;
  bool _isPressed = false;

  // Couleurs par groupe (selon la photo)
  final Map<String, Color> colors = {
    'drinks': const Color(0xFF1ABC9C), // Vert (comme dans la photo pour SOFT actif)
    'spirits': const Color(0xFF9B59B6),
    'entrees': const Color(0xFF1ABC9C),
    'plats': const Color(0xFF1ABC9C),
    'desserts': const Color(0xFF1ABC9C),
  };

  @override
  void initState() {
    super.initState();
    _buildGroupToCategories();
  }

  // Détecte si un type appartient à un sous-groupe de food
  String? _detectFoodSubGroup(String type) {
    if (type.isEmpty) return null;
    final t = type.toLowerCase();
    if (t.contains('entrée') || t.contains('entree')) return 'entrees';
    if (t.contains('dessert') || t.contains('patisserie') || t.contains('glace')) return 'desserts';
    // Tout le reste dans food est considéré comme "plats"
    return 'plats';
  }

  void _buildGroupToCategories() {
    final categories = (widget.menu['categories'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final map = <String, List<Map<String, dynamic>>>{};
    
    // Séparer le groupe "food" en sous-groupes basés sur les types
    final foodCategories = <Map<String, dynamic>>[];
    final entreesCategories = <Map<String, dynamic>>[];
    final platsCategories = <Map<String, dynamic>>[];
    final dessertsCategories = <Map<String, dynamic>>[];
    
    for (final cat in categories) {
      final group = (cat['group'] as String?) ?? 'food';
      
      if (group == 'food') {
        // Analyser les items pour déterminer le sous-groupe
        final items = (cat['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        if (items.isEmpty) continue;
        
        // Compter les items par sous-groupe
        final entreesItems = <Map<String, dynamic>>[];
        final platsItems = <Map<String, dynamic>>[];
        final dessertsItems = <Map<String, dynamic>>[];
        
        for (final item in items) {
          final type = (item['type'] as String?) ?? '';
          final subGroup = _detectFoodSubGroup(type);
          if (subGroup == 'entrees') {
            entreesItems.add(item);
          } else if (subGroup == 'desserts') {
            dessertsItems.add(item);
          } else {
            // Par défaut, tout ce qui n'est pas entrée ou dessert est un plat
            platsItems.add(item);
          }
        }
        
        // Ajouter les items à leurs sous-groupes respectifs
        if (entreesItems.isNotEmpty) {
          entreesCategories.add({
            ...cat,
            'items': entreesItems,
          });
        }
        if (platsItems.isNotEmpty) {
          platsCategories.add({
            ...cat,
            'items': platsItems,
          });
        }
        if (dessertsItems.isNotEmpty) {
          dessertsCategories.add({
            ...cat,
            'items': dessertsItems,
          });
        }
      } else {
        // Groupes directs (drinks, spirits)
        map.putIfAbsent(group, () => []).add(cat);
      }
    }
    
    // Ajouter les sous-groupes de food
    if (entreesCategories.isNotEmpty) {
      map['entrees'] = entreesCategories;
    }
    if (platsCategories.isNotEmpty) {
      map['plats'] = platsCategories;
    }
    if (dessertsCategories.isNotEmpty) {
      map['desserts'] = dessertsCategories;
    }
    
    setState(() {
      groupToCategories = map;
      if (activeGroup == null && map.isNotEmpty) {
        // Prioriser drinks, puis spirits, puis entrees, plats, desserts
        if (map.containsKey('drinks')) {
          activeGroup = 'drinks';
        } else if (map.containsKey('spirits')) {
          activeGroup = 'spirits';
        } else if (map.containsKey('entrees')) {
          activeGroup = 'entrees';
        } else if (map.containsKey('plats')) {
          activeGroup = 'plats';
        } else if (map.containsKey('desserts')) {
          activeGroup = 'desserts';
        } else {
          activeGroup = map.keys.first;
        }
        _setDefaultTypeForGroup(activeGroup!);
      }
    });
  }

  void _setDefaultTypeForGroup(String group) {
    final typesList = _typesForActiveGroup();
    if (typesList.isEmpty) {
      activeType = null;
      return;
    }
    
    setState(() {
      // Priorités par défaut selon le groupe
          if (group == 'drinks') {
            activeType = typesList.any((t) => t.toLowerCase().contains('boisson froide'))
                ? typesList.firstWhere((t) => t.toLowerCase().contains('boisson froide'))
                : (typesList.isNotEmpty ? typesList.first : null);
          } else if (group == 'entrees') {
            activeType = typesList.any((t) => t.toLowerCase().contains('entrée froide'))
                ? typesList.firstWhere((t) => t.toLowerCase().contains('entrée froide'))
                : (typesList.isNotEmpty ? typesList.first : null);
          } else if (group == 'plats') {
            activeType = typesList.any((t) => t.toLowerCase().contains('plat tunisien'))
                ? typesList.firstWhere((t) => t.toLowerCase().contains('plat tunisien'))
                : (typesList.isNotEmpty ? typesList.first : null);
          } else {
        activeType = typesList.isNotEmpty ? typesList.first : null;
      }
      
      // Si le type par défaut est VIN, sélectionner Vin blanc par défaut
      if (activeType == '__VIN__') {
        activeWineSubType = 'Vin blanc';
      }
    });
  }

  String _labelForGroup(String g) {
    switch (g) {
      case 'drinks':
        return 'SOFT';
      case 'spirits':
        return 'SPIRITUEUX';
      case 'entrees':
        return 'ENTRÉES';
      case 'plats':
        return 'PLATS';
      case 'desserts':
        return 'DESSERTS';
      default:
        return g.toUpperCase();
    }
  }

  List<String> _typesForActiveGroup() {
    final g = activeGroup;
    if (g == null) return const [];
    final seen = <String>{};
    final orderedRaw = <String>[];
    
    for (final c in (groupToCategories[g] ?? const [])) {
      for (final it in ((c['items'] as List?) ?? const [])) {
        final t = (it as Map)['type'] as String?;
        if (t != null && t.isNotEmpty && !seen.contains(t)) {
          seen.add(t);
          orderedRaw.add(t);
        }
      }
    }
    
    // Regrouper les types de vin
    final isWineType = (String x) {
      final xl = x.toLowerCase();
      return xl.startsWith('vin ');
    };
    
    final result = <String>[];
    bool vinsAdded = false;
    for (final t in orderedRaw) {
      if (isWineType(t)) {
        if (!vinsAdded) {
          result.add('__VIN__');
          vinsAdded = true;
        }
        continue;
      }
      result.add(t);
    }
    
    // Tri spécifique pour les Spiritueux (Bière, Vin, le reste)
    if (activeGroup == 'spirits') {
      result.sort((a, b) {
        final aLower = a.toLowerCase();
        final bLower = b.toLowerCase();
        
        // 1. Bière en premier
        final aIsBeer = aLower.contains('biere') || aLower.contains('bière');
        final bIsBeer = bLower.contains('biere') || bLower.contains('bière');
        if (aIsBeer && !bIsBeer) return -1;
        if (!aIsBeer && bIsBeer) return 1;
        
        // 2. Vin en deuxième
        final aIsVin = a == '__VIN__';
        final bIsVin = b == '__VIN__';
        if (aIsVin && !bIsVin) return -1;
        if (!aIsVin && bIsVin) return 1;
        
        // 3. Le reste
        return a.compareTo(b);
      });
    }

    return result;
  }

  List<Map<String, dynamic>> _itemsForActiveType() {
    final g = activeGroup;
    final t = activeType;
    if (g == null || t == null) return const [];
    
    final result = <Map<String, dynamic>>[];
    for (final c in (groupToCategories[g] ?? const [])) {
      final items = (c['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final it in items) {
        final itType = (it['type'] as String?) ?? '';
        if (t == '__VIN__') {
          if (activeWineSubType != null) {
            if (itType.toLowerCase() == activeWineSubType!.toLowerCase()) result.add(it);
          } else {
            if (itType.toLowerCase().startsWith('vin ')) result.add(it);
          }
        } else {
          if (itType == t) result.add(it);
        }
      }
    }
    return result;
  }

  List<String> _orderedGroups() {
    final groups = groupToCategories.keys.toList();
    final order = ['drinks', 'spirits', 'entrees', 'plats', 'desserts'];
    groups.sort((a, b) {
      final indexA = order.indexOf(a);
      final indexB = order.indexOf(b);
      if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
      if (indexA != -1) return -1;
      if (indexB != -1) return 1;
      return a.compareTo(b);
    });
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Boutons de groupes (onglets principaux) - Style de la photo
        SizedBox(
          height: 54,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: _orderedGroups().map((group) {
              final isActive = group == activeGroup;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      activeGroup = group;
                      activeWineSubType = null;
                      _setDefaultTypeForGroup(group);
        });
      },
      style: ElevatedButton.styleFrom(
                    backgroundColor: isActive 
                        ? (colors[group] ?? const Color(0xFF1ABC9C))
                        : Colors.grey.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    elevation: isActive ? 2 : 0,
      ),
      child: Text(
        _labelForGroup(group),
        style: TextStyle(
          fontSize: 16,
          fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        // Boutons de types (sous-catégories) - Style de la photo
        if (activeGroup != null && activeType != null)
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: _buildTypeButtons(),
        ),
      ),
        // Grille d'articles - Style de la photo (boutons verts carrés)
        Expanded(
          child: _buildItemsGrid(),
        ),
      ],
    );
  }

  List<Widget> _buildTypeButtons() {
    if (activeType == '__VIN__') {
      // Afficher les sous-types de vin
      return const ['Vin blanc', 'Vin rosé', 'Vin rouge', 'Vin français'].map((wt) {
        final isActive = activeWineSubType == wt;
        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                activeWineSubType = wt;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive 
                  ? const Color(0xFF3498DB)
                  : Colors.grey.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              elevation: isActive ? 2 : 0,
            ),
            child: Text(
              wt,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList();
    } else {
      // Afficher les types normaux (sous-catégories)
      return _typesForActiveGroup().map((t) {
        final isActive = t == activeType;
        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                activeType = t;
                if (t == '__VIN__') {
                  activeWineSubType = 'Vin blanc';
                } else {
                  activeWineSubType = null;
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive 
                  ? const Color(0xFF3498DB) // Bleu pour actif (comme dans la photo)
                  : Colors.grey.shade700, // Gris pour inactif
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              elevation: isActive ? 2 : 0,
            ),
            child: Text(
              t == '__VIN__' ? 'Vins' : t,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList();
    }
  }

  Widget _buildItemsGrid() {
    final items = _itemsForActiveType();
    
    if (items.isEmpty) {
      return const Center(
        child: Text('Aucun article dans cette catégorie', style: TextStyle(color: Colors.grey, fontSize: 16)),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.8, // Rectangulaire (plus large que haut) comme dans l'ancien menu
      ),
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        final name = item['name'] as String;
        final price = (item['price'] as num).toDouble();
        final available = (item['available'] ?? true) == true;
        
        final itemId = item['id'] as int;
        final isSelected = _selectedItemId == itemId;
        
        return InkWell(
          onTap: available ? () {
            // Feedback visuel et tactile immédiat
            setState(() {
              _selectedItemId = itemId;
              _isPressed = true;
            });
            
            // Feedback tactile
            try { 
              HapticFeedback.selectionClick(); 
            } catch (_) {}
            
            // Réinitialiser le feedback après 300ms
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                setState(() {
                  _selectedItemId = null;
                  _isPressed = false;
                });
              }
            });
            
            // Appeler la fonction de sélection
            widget.onItemSelected(item);
          } : null,
          child: Container(
            decoration: BoxDecoration(
              color: available
                    ? (isSelected 
                      ? const Color(0xFF27AE60) // Vert plus vif pour sélection
                      : const Color(0xFF1ABC9C)) // Vert standard (comme dans la photo)
                  : Colors.grey.shade400,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: isSelected ? Colors.green.withOpacity(0.5) : Colors.black26, 
                  blurRadius: isSelected ? 8 : 4, 
                  offset: const Offset(0, 2)
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Center(
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${price.toStringAsFixed(3)} TND',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
