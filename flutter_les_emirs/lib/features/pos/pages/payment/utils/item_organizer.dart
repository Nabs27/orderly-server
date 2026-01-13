/// Helper pour organiser les articles par catégories (boissons, entrées, plats, desserts)
class ItemOrganizer {
  /// Organise une liste d'articles bruts par catégories
  /// 
  /// 🆕 REGROUPEMENT VISUEL : Regroupe les articles identiques pour l'affichage
  /// tout en conservant toutes les métadonnées (orderId, noteId) pour le backend
  static List<Map<String, dynamic>> organizeFromRawItems(List<Map<String, dynamic>> rawItems) {
    // Si la liste est vide, retourner une liste vide
    if (rawItems.isEmpty) {
      return [];
    }
    
    // 🆕 Vérifier si les articles ont des métadonnées (orderId, noteId)
    final hasMetadata = rawItems.isNotEmpty && 
        (rawItems.first.containsKey('orderId') || rawItems.first.containsKey('noteId'));
    
    if (hasMetadata) {
      // 🆕 REGROUPEMENT VISUEL avec conservation des métadonnées
      return _organizeWithGroupingAndMetadata(rawItems);
    }
    
    // Sinon, regrouper par (id, name) en cumulant les quantités (ancien comportement)
    final Map<int, Map<String, dynamic>> groupedItems = {};
    for (final item in rawItems) {
      final id = item['id'] as int;
      final name = item['name'] as String;
      final price = (item['price'] as num).toDouble();
      final quantity = (item['quantity'] as num).toInt();
      if (groupedItems.containsKey(id)) {
        groupedItems[id]!['quantity'] = (groupedItems[id]!['quantity'] as int) + quantity;
      } else {
        groupedItems[id] = {
          'id': id,
          'name': name,
          'price': price,
          'quantity': quantity,
        };
      }
    }

    // Organiser par catégories
    return _organizeByCategories(groupedItems.values.toList());
  }
  
  /// 🆕 Organise les articles avec regroupement visuel ET conservation des métadonnées
  /// 
  /// BONNES PRATIQUES POS :
  /// - ✅ Regroupe visuellement les articles identiques (même ID/nom) pour faciliter la vue
  /// - ✅ Additionne les quantités pour l'affichage
  /// - ✅ Préserve TOUTES les métadonnées (orderId/noteId) dans 'sources' pour le backend
  /// - ✅ Permet à payMultiOrders() de répartir correctement les quantités entre commandes/notes
  /// - ✅ Organise par catégories pour une meilleure UX
  static List<Map<String, dynamic>> _organizeWithGroupingAndMetadata(List<Map<String, dynamic>> items) {
    // Regrouper par (id, name) en cumulant les quantités visuellement
    // mais conserver toutes les sources (orderId, noteId, quantity) pour le backend
    final Map<String, Map<String, dynamic>> groupedItems = {};
    
    for (final item in items) {
      // 🎯 Utiliser une clé String pour éviter les problèmes de type ID
      final id = item['id'].toString();
      final name = item['name'] as String? ?? 'Article inconnu';
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
      final orderId = item['orderId'];
      final noteId = item['noteId'];
      
      final key = "$id-$name-$price"; // 🎯 Regrouper par ID, Nom ET Prix pour éviter les erreurs de total
      
      if (groupedItems.containsKey(key)) {
        // Article déjà présent : additionner la quantité visuelle
        groupedItems[key]!['quantity'] = (groupedItems[key]!['quantity'] as int) + quantity;
        
        // Ajouter cette source à la liste des sources
        final sources = groupedItems[key]!['sources'] as List<Map<String, dynamic>>;
        sources.add({
          'orderId': orderId,
          'noteId': noteId,
          'itemId': int.tryParse(id) ?? id, // 🆕 CORRECTION : Stocker l'ID original de la source
          'quantity': quantity,
        });
        
        // Si le noteId est différent, on met null au top level pour indiquer multi-notes
        if (groupedItems[key]!['noteId'] != noteId) {
          groupedItems[key]!['noteId'] = null;
        }
      } else {
        // Nouvel article : créer avec première source
        groupedItems[key] = {
          'uniqueKey': key, // 🆕 Clé unique pour la sélection (ID + Nom + Prix)
          'id': int.tryParse(id) ?? id, // Garder l'ID original si possible
          'name': name,
          'price': price,
          'quantity': quantity, // Quantité totale pour affichage
          'noteId': noteId, // NoteId initial
          'sources': [
            {
              'orderId': orderId,
              'noteId': noteId,
              'itemId': int.tryParse(id) ?? id, // 🆕 CORRECTION : Stocker l'ID original de la source
              'quantity': quantity,
            }
          ],
        };
      }
    }
    
    // Organiser par catégories
    return _organizeByCategories(groupedItems.values.toList());
  }
  
  /// Organise les articles sans les regrouper (pour préserver orderId/noteId)
  /// 
  /// ⚠️ DÉPRÉCIÉ : Utilisé uniquement pour compatibilité
  /// Utiliser _organizeWithGroupingAndMetadata() à la place
  static List<Map<String, dynamic>> _organizeWithoutGrouping(List<Map<String, dynamic>> items) {
    // 🎯 BONNE PRATIQUE POS : Utiliser une Map avec clé unique pour préserver
    // la traçabilité tout en évitant les doublons dans la même commande/note
    // Clé format: "orderId-noteId-itemId" garantit l'unicité par provenance
    
    final Map<String, Map<String, dynamic>> byOrderAndNote = {};
    final List<Map<String, dynamic>> duplicateItems = []; // Pour détecter les problèmes
    
    for (final item in items) {
      final orderId = item['orderId'];
      final noteId = item['noteId'];
      final itemId = item['id'];
      
      if (orderId != null && noteId != null) {
        // Créer une clé unique qui combine orderId, noteId et id
        final key = '$orderId-$noteId-$itemId';
        
        // Vérifier si on a déjà un article avec cette clé
        if (byOrderAndNote.containsKey(key)) {
          // Dans un POS normal, cela ne devrait pas arriver car les articles
          // dans une même note sont regroupés par quantité.
          // Mais on préserve quand même en ajoutant un suffixe pour éviter la perte
          print('[ItemOrganizer] ⚠️ Article dupliqué détecté: $key - Quantité: ${item['quantity']}');
          duplicateItems.add(item);
        } else {
          byOrderAndNote[key] = Map<String, dynamic>.from(item);
        }
      } else {
        // Fallback : préserver l'article même sans métadonnées complètes
        print('[ItemOrganizer] ⚠️ Article sans métadonnées complètes: $itemId - ${item['name']}');
        final fallbackKey = 'fallback-$itemId-${byOrderAndNote.length}';
        byOrderAndNote[fallbackKey] = Map<String, dynamic>.from(item);
      }
    }
    
    // Si on a des doublons, les ajouter avec une clé différente
    for (var i = 0; i < duplicateItems.length; i++) {
      final item = duplicateItems[i];
      final orderId = item['orderId'];
      final noteId = item['noteId'];
      final itemId = item['id'];
      final key = '$orderId-$noteId-$itemId-duplicate-$i';
      byOrderAndNote[key] = Map<String, dynamic>.from(item);
    }
    
    // Organiser par catégories en préservant toutes les instances
    return _organizeByCategories(byOrderAndNote.values.toList());
  }
  
  /// Organise les articles par catégories (sans regroupement)
  static List<Map<String, dynamic>> _organizeByCategories(List<Map<String, dynamic>> items) {
    // 🆕 CORRECTION CRITIQUE : Créer un Set pour tracker les articles déjà ajoutés AVANT de commencer
    // Utiliser une clé basée sur id-name-price pour une identification unique
    String _getItemKey(Map<String, dynamic> item) {
      final id = item['id']?.toString() ?? '';
      final name = item['name']?.toString() ?? '';
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      return '$id-$name-${price.toStringAsFixed(2)}';
    }
    
    final Set<String> addedKeys = {}; // Track des articles déjà ajoutés
    final List<Map<String, dynamic>> organizedItems = [];

    bool _isName(Map<String, dynamic> item, List<String> tokens) {
      final n = (item['name'] as String).toLowerCase();
      for (final t in tokens) { 
        if (n.contains(t)) return true; 
      }
      return false;
    }

    List<Map<String, dynamic>> _pick(List<String> tokens) {
      final list = items.where((it) {
        final key = _getItemKey(it);
        // 🆕 Vérifier si l'article correspond aux tokens ET n'a pas déjà été ajouté
        return _isName(it, tokens) && !addedKeys.contains(key);
      }).toList();
      
      // 🆕 Marquer les articles comme ajoutés AVANT de les ajouter à organizedItems
      for (final item in list) {
        addedKeys.add(_getItemKey(item));
      }
      
      list.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      return list;
    }

    // 1. Boissons
    organizedItems.addAll(_pick(['eau', 'coca', 'sprite', 'celtia', 'beck', 'pastis', 'fanta']));
    // 2. Entrées
    organizedItems.addAll(_pick(['salade', 'carpaccio']));
    // 3. Plats
    organizedItems.addAll(_pick(['camembert', 'seiches', 'cordon', 'entrecôte', 'médaillons', 'brochettes', 'côte', 'poulet', 'ojja', 'couscous']));
    // 4. Desserts
    organizedItems.addAll(_pick(['tiramisu', 'chocolate', 'dessert', 'moelleux']));

    // 5. Autres non classés
    final others = items.where((it) {
      final key = _getItemKey(it);
      return !addedKeys.contains(key); // 🆕 Vérifier si pas déjà ajouté
    }).toList();
    others.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    organizedItems.addAll(others);

    return organizedItems;
  }
}

