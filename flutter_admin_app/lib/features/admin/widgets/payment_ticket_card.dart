import 'package:flutter/material.dart';

/// Widget générique pour afficher un ticket de paiement/remise
/// Réutilisable dans : KPI remises, historique, Rapport X
class PaymentTicketCard extends StatelessWidget {
  final String table;
  final String? server;
  final String? noteName;
  final String? timestamp;
  final List<Map<String, dynamic>> items;
  final double subtotal;
  final double? discountAmount;
  final double? discount; // Taux de remise
  final bool? isPercentDiscount;
  final double amount; // Montant final
  final String? paymentMode;
  final int? covers;
  final String? discountClientName; // 🆕 Nom du client pour justifier la remise

  const PaymentTicketCard({
    super.key,
    required this.table,
    this.server,
    this.noteName,
    this.timestamp,
    required this.items,
    required this.subtotal,
    this.discountAmount,
    this.discount,
    this.isPercentDiscount,
    required this.amount,
    this.paymentMode,
    this.covers,
    this.discountClientName,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveDiscountAmount = discountAmount ?? 
        (discount != null && discount! > 0 
            ? (isPercentDiscount == true 
                ? (subtotal * discount! / 100) 
                : discount!)
            : 0.0);

    // Style identique à TicketPreviewDialog - simple ticket de caisse
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Text(
            'LES EMIRS RESTAURANT',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('Table: $table'),
          if (timestamp != null)
            Text('Date: ${_formatDate(timestamp!)}')
          else
            Text('Date: ${DateTime.now().toString().substring(0, 16)}'),
          if (noteName != null && noteName != 'Note Principale') ...[
            const SizedBox(height: 2),
            Text('Note: $noteName', style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
          // 🆕 Afficher le nom du client si présent
          if (discountClientName != null && discountClientName!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('Client: $discountClientName', style: TextStyle(color: Colors.blue.withValues(alpha: 0.7), fontWeight: FontWeight.w500)),
          ],
          if (covers != null && covers! > 0) ...[
            const SizedBox(height: 2),
            Text('Couverts: $covers'),
          ],
          const SizedBox(height: 8),
          const Divider(),
          
          // Articles - Format exact comme TicketPreviewDialog : "nom xquantité"
          // Trier par type : boissons → entrées → plats → desserts
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Aucun article', style: TextStyle(fontStyle: FontStyle.italic)),
            )
          else ...[
            ..._sortItemsByCategory(items).map<Widget>((it) {
              final price = (it['price'] as num?)?.toDouble() ?? 0.0;
              final quantity = (it['quantity'] as num?)?.toInt() ?? 0;
              final subtotal = price * quantity;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('$quantity x ${it['name']}')),
                    Text('${subtotal.toStringAsFixed(2)} TND'),
                  ],
                ),
              );
            }),
            const Divider(),
          ],
          
          // Affichage des remises si appliquées - Format exact comme TicketPreviewDialog
          if (effectiveDiscountAmount > 0.01) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Sous-total:'),
                Text('${subtotal.toStringAsFixed(2)} TND'),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  discount != null
                      ? 'Remise ${discount!.toStringAsFixed(0)}${isPercentDiscount == true ? '%' : ' TND'}:'
                      : 'Remise:',
                ),
                Text(
                  '-${effectiveDiscountAmount.toStringAsFixed(2)} TND',
                  style: TextStyle(color: Colors.red.shade600),
                ),
              ],
            ),
            const Divider(),
          ],
          
          // Total final - Format exact comme TicketPreviewDialog
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '${amount.toStringAsFixed(2)} TND',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Merci de votre visite !',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    // Format identique à TicketPreviewDialog : YYYY-MM-DD HH:MM
    return dt.toString().substring(0, 16);
  }

  /// Détermine le type d'article basé sur le type/group/category du menu (pour tri ergonomique)
  /// Ordre: boisson (0) → entrée (1) → plat (2) → dessert (3)
  /// Tous les articles appartiennent forcément à une famille du menu
  int _getItemTypeOrder(Map<String, dynamic> item) {
    // 🎯 Utiliser directement le type de l'item depuis le menu (plus fiable)
    final itemType = (item['type'] as String? ?? '').toLowerCase();
    final categoryName = (item['categoryName'] as String? ?? '').toLowerCase();
    final name = (item['name'] as String? ?? '').toLowerCase();
    
    // 🎯 Détection par CATÉGORIE d'abord (plus fiable que le nom seul)
    // Noms de catégories du menu: "Boissons — Soft", "Boissons — Spiritueux", "Vins...", "Entrées...", "Spécialités tunisiennes", "Les Pâtes", "Volailles", "Viandes", "Poissons", "Desserts"
    
    // 1️⃣ BOISSONS (priorité 0 - affichées en premier)
    // Catégories: "Boissons — Soft", "Boissons — Spiritueux", "Vins Blancs", "Vins Rosés", "Vins Rouges", "Vins Français", "Champagnes"
    // Types: "Boisson froide", "Boisson chaude", "Apéritif", "Digestif", "Whisky", "Bière", "Cocktail", "Shot", "Vin blanc", "Vin rosé", "Vin rouge", "Vin français", "Champagne"
    if (categoryName.contains('boisson') ||
        categoryName.contains('spiritueux') ||
        categoryName.contains('vin') ||
        categoryName.contains('champagne') ||
        itemType.contains('boisson') ||
        itemType.contains('apéritif') ||
        itemType.contains('aperitif') ||
        itemType.contains('digestif') ||
        itemType.contains('whisky') ||
        itemType.contains('bière') ||
        itemType.contains('biere') ||
        itemType.contains('cocktail') ||
        itemType.contains('shot') ||
        itemType.startsWith('vin ') ||
        itemType.contains('champagne') ||
        name.contains('coca') ||
        name.contains('fanta') ||
        name.contains('sprite') ||
        name.contains('boga') ||
        name.contains('schweppes') ||
        name.contains('eau') ||
        name.contains('jus') ||
        name.contains('café') ||
        name.contains('cafe') ||
        name.contains('thé') ||
        name.contains('the') ||
        name.contains('vodka') ||
        name.contains('gin') ||
        name.contains('rhum') ||
        name.contains('whisky') ||
        name.contains('bier') ||
        name.contains('mojito') ||
        name.contains('cocktail') ||
        name.contains('vin') ||
        name.contains('champagne') ||
        name.contains('pastis') ||
        name.contains('ricard') ||
        name.contains('anisette') ||
        name.contains('ciroc') ||
        name.contains('greygoose') ||
        name.contains('smirnoff') ||
        name.contains('absolut') ||
        name.contains('bombay') ||
        name.contains('gordon') ||
        name.contains('martini') ||
        name.contains('campari') ||
        name.contains('thibarine') ||
        name.contains('cédratine') ||
        name.contains('cedratine') ||
        name.contains('boukha') ||
        name.contains('hennessy') ||
        name.contains('cointreau') ||
        name.contains('amaretto') ||
        name.contains('bailey') ||
        name.contains('limoncello') ||
        name.contains('malibu') ||
        name.contains('chivas') ||
        name.contains('walker') ||
        name.contains('jack daniel') ||
        name.contains('glenmorangie') ||
        name.contains('celtia') ||
        name.contains('beck') ||
        name.contains('royal passion') ||
        name.contains('pina colada') ||
        name.contains('melon breeze') ||
        name.contains('swimming pool') ||
        name.contains('manhattan') ||
        name.contains('red hot') ||
        name.contains('tequila') ||
        name.contains('b-52') ||
        name.contains('b52') ||
        name.contains('mouton cadet') ||
        name.contains('miraval') ||
        name.contains('minuty') ||
        name.contains('chopin') ||
        name.contains('cybele')) {
      return 0; // Boissons
    }
    
    // 2️⃣ ENTREES (priorité 1)
    // Catégories: "Entrées froides", "Entrées chaudes"
    // Types: "Entrée froide", "Entrée chaude"
    if (categoryName.contains('entrée') ||
        categoryName.contains('entree') ||
        itemType.contains('entrée') ||
        itemType.contains('entree') ||
        itemType.contains('hors') ||
        name.contains('salade') ||
        name.contains('soupe') ||
        name.contains('carpaccio') ||
        name.contains('burrata') ||
        name.contains('foie gras') ||
        name.contains('mozzarella') ||
        name.contains('brick') ||
        name.contains('camembert') ||
        name.contains('seiches') ||
        name.contains('calmar doré') ||
        name.contains('calmar dore') ||
        name.contains('moules') ||
        (name.contains('crevettes') && (name.contains('ail') || name.contains('croustillant')))) {
      return 1; // Entrées
    }
    
    // 3️⃣ PLATS (priorité 2)
    // Catégories: "Spécialités tunisiennes", "Les Pâtes", "Volailles", "Viandes", "Poissons"
    // Types: "Plat tunisien", "Pâtes", "Volaille", "Viande", "Poisson"
    if (categoryName.contains('spécialité') ||
        categoryName.contains('specialite') ||
        categoryName.contains('pâtes') ||
        categoryName.contains('pates') ||
        categoryName.contains('volaille') ||
        categoryName.contains('viande') ||
        categoryName.contains('poisson') ||
        itemType.contains('plat') ||
        itemType.contains('pâtes') ||
        itemType.contains('pates') ||
        itemType.contains('volaille') ||
        itemType.contains('viande') ||
        itemType.contains('poisson') ||
        name.contains('ojja') ||
        name.contains('kamounia') ||
        name.contains('couscous') ||
        name.contains('calamar farci') ||
        name.contains('ravioli') ||
        name.contains('penne') ||
        name.contains('spaghetti') ||
        name.contains('tagliatelle') ||
        name.contains('rigatoni') ||
        name.contains('cordon') ||
        name.contains('poulet') ||
        name.contains('côte') ||
        name.contains('cote') ||
        name.contains('entrecôte') ||
        name.contains('entrecote') ||
        name.contains('filet') ||
        name.contains('brochette') ||
        name.contains('mérou') ||
        name.contains('merou') ||
        name.contains('loup') ||
        name.contains('reine') ||
        name.contains('langouste') ||
        name.contains('gargoulette') ||
        name.contains('médaille') ||
        name.contains('medaille') ||
        name.contains('émincé') ||
        name.contains('emince') ||
        name.contains('stroganoff') ||
        name.contains('poivre') ||
        name.contains('champignon') ||
        name.contains('roquefort') ||
        name.contains('parmesan') ||
        name.contains('cèpes') ||
        name.contains('cepes') ||
        name.contains('truffes') ||
        name.contains('rossini') ||
        name.contains('poisson du jour') ||
        name.contains('crevettes royales')) {
      return 2; // Plats
    }
    
    // 4️⃣ DESSERTS (priorité 3)
    // Catégorie: "Desserts"
    // Type: "Dessert"
    if (categoryName.contains('dessert') ||
        itemType.contains('dessert') ||
        name.contains('tiramisu') ||
        name.contains('moelleux') ||
        name.contains('affogato') ||
        name.contains('glace') ||
        name.contains('sorbet') ||
        name.contains('nougat') ||
        name.contains('iced nougat') ||
        name.contains('patisserie') ||
        name.contains('pâtisserie')) {
      return 3; // Desserts
    }
    
    // 🎯 Si aucun type détecté, considérer comme plat par défaut (groupe "food")
    // Car tous les articles appartiennent à une famille du menu (drinks, spirits, ou food)
    return 2; // Plats par défaut (groupe "food")
  }

  /// Trie les articles par type : boissons → entrées → plats → desserts
  List<Map<String, dynamic>> _sortItemsByCategory(List<Map<String, dynamic>> items) {
    final sorted = List<Map<String, dynamic>>.from(items);
    sorted.sort((a, b) {
      final orderA = _getItemTypeOrder(a);
      final orderB = _getItemTypeOrder(b);
      if (orderA != orderB) {
        return orderA.compareTo(orderB); // Trier par type d'abord
      }
      // Si même type, trier par nom alphabétiquement
      final nameA = (a['name'] as String? ?? '').toLowerCase();
      final nameB = (b['name'] as String? ?? '').toLowerCase();
      return nameA.compareTo(nameB);
    });
    return sorted;
  }
}

