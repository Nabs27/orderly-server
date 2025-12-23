import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../core/api_client.dart';
import '../../core/cart_service.dart';
import '../../core/lang_service.dart';
import '../../core/strings.dart';
import '../cart/cart_page.dart';
import 'options.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});
  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  Map<String, dynamic>? data;
  String? error;
  // ergonomie: onglets + sous-catégories
  final cart = CartService.instance;
  // Animation "fly to cart"
  final GlobalKey _cartButtonKey = GlobalKey();
  Map<String, List<Map<String, dynamic>>> groupToCategories = {};
  String? activeGroup; // 'drinks' | 'spirits' | 'food'
  bool showTypes = false;
  String? activeType; // ex: 'Entrée froide', '__VIN__' pour Vin regroupé
  String? activeWineSubType; // 'Vin blanc' | 'Vin rosé' | 'Vin rouge' | 'Vin français'
  String? tableCode; // pour les demandes de service
  io.Socket? socket;

  @override
  void initState() {
    super.initState();
    CartService.instance.load();
    _load();
    _connectSocket();
  }

  @override
  void dispose() {
    socket?.dispose();
    super.dispose();
  }

  void _connectSocket() {
    final base = ApiClient.dio.options.baseUrl;
    final uri = base.replaceAll(RegExp(r"/+$"), '');
    final s = io.io(uri, io.OptionBuilder().setTransports(['websocket']).setExtraHeaders({'Origin': uri}).build());
    socket = s;
    
    s.on('menu:updated', (payload) {
      print('[menu] Socket event: menu updated');
      // Recharger le menu automatiquement
      _load(preserveNavigation: true);
    });
    
    s.connect();
  }

  Future<void> _load({bool preserveNavigation = false}) async {
    try {
      await LangService.instance.load();
      final res = await ApiClient.dio.get('/menu/les-emirs', queryParameters: {'lng': LangService.instance.lang});
      final d = res.data as Map<String, dynamic>;
      final cats = (d['categories'] as List).cast<Map<String, dynamic>>();
      // construire groupToCategories
      final map = <String, List<Map<String, dynamic>>>{};
      for (final c in cats) {
        final g = (c['group'] as String?) ?? 'food';
        map.putIfAbsent(g, () => []).add(c);
      }
      // ordre: drinks, spirits, food
      String pickDefaultGroup() {
        if (map.containsKey('drinks')) return 'drinks';
        if (map.containsKey('spirits')) return 'spirits';
        return map.keys.isNotEmpty ? map.keys.first : 'food';
      }
      final prevGroup = activeGroup;
      final prevType = activeType;
      final prevWine = activeWineSubType;
      final prevShowTypes = showTypes;
      setState(() {
        data = d;
        groupToCategories = map;
        if (preserveNavigation) {
          activeGroup = (prevGroup != null && map.containsKey(prevGroup)) ? prevGroup : pickDefaultGroup();
          showTypes = prevShowTypes;
          activeType = prevType;
          activeWineSubType = prevWine;
        } else {
        activeGroup = pickDefaultGroup();
        showTypes = true; // forcer un choix d'abord
        activeType = null;
          activeWineSubType = null;
        }
      });
    } on DioException catch (e) {
      setState(() => error = e.message);
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  String? _firstTypeForGroup(String? group) {
    if (group == null) return null;
    final cats = groupToCategories[group] ?? const [];
    final types = <String>{};
    for (final c in cats) {
      for (final it in ((c['items'] as List?) ?? const [])) {
        final t = (it as Map)['type'] as String?;
        if (t != null && t.isNotEmpty) types.add(t);
      }
    }
    if (types.isEmpty) return null;
    // prioriser les "Boisson"
    final sorted = types.toList()
      ..sort((a,b){
        int rank(String s) => s.toLowerCase().contains('boisson') ? 0 : 1;
        final ra = rank(a), rb = rank(b);
        if (ra != rb) return ra - rb;
        return a.compareTo(b);
      });
    return sorted.first;
  }

  String _labelForGroup(String g) {
    switch (g) {
      case 'drinks': return 'Soft';  // Changé de 'Boissons' à 'Soft'
      case 'spirits': return 'Spiritueux';
      case 'services': return 'Services';
      case 'food': return 'Plats';  // Par défaut pour 'food'
      default: return Strings.t('dishes');
    }
  }

  String _pluralTypeLabel(String t) {
    final l = t.toLowerCase();
    if (l == 'boisson') return 'Boissons';
    if (l == 'boisson chaude') return 'Boissons chaudes';
    if (l == 'boisson froide') return 'Boissons froides';
    if (l == 'viande' || l.contains('viande')) return 'Viandes';
    if (l == 'volaille' || l.contains('volaille')) return 'Volailles';
    if (l == 'poisson' || l.contains('poisson')) return 'Poissons';
    if (l == 'plat tunisien' || l.contains('plat tunisien')) return 'Plats tunisiens';
    if (l == 'entrée chaude' || l.contains('entrée chaude')) return 'Entrées chaudes';
    if (l == 'entrée froide' || l.contains('entrée froide')) return 'Entrées froides';
    if (l == 'apéritif' || l.contains('apéritif')) return 'Apéritifs';
    if (l == 'digestif' || l.contains('digestif')) return 'Digestifs';
    if (l == 'whisky' || l.contains('whisky')) return 'Whiskies';
    if (l == 'bière' || l.contains('bière')) return 'Bières';
    if (l == 'cocktail' || l.contains('cocktail')) return 'Cocktails';
    if (l == 'shot' || l.contains('shot')) return 'Shots';
    if (l == 'champagne' || l.contains('champagne')) return 'Champagnes';
    return t;
  }

  // Ordre souhaité pour les types de spiritueux
  int _getTypeOrder(String type) {
    final t = type.toLowerCase();
    if (t == 'apéritif' || t.contains('apéritif')) return 1;
    if (t == 'whisky' || t.contains('whisky')) return 2;
    if (t == 'bière' || t.contains('bière')) return 3;
    if (t == 'cocktail' || t.contains('cocktail')) return 4;
    if (t == 'shot' || t.contains('shot')) return 5;
    if (t == 'digestif' || t.contains('digestif')) return 6;  // Digestifs en dernier !
    if (t.startsWith('vin ')) return 7;
    if (t == 'champagne' || t.contains('champagne')) return 8;
    return 0;  // Par défaut (pour food, etc.)
  }

  // Construit la liste des types avec regroupement des vins en une seule entrée
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
    
    // Trier selon l'ordre personnalisé (pour les spiritueux)
    if (g == 'spirits') {
      orderedRaw.sort((a, b) {
        final orderA = _getTypeOrder(a);
        final orderB = _getTypeOrder(b);
        return orderA.compareTo(orderB);
      });
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
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Menu - Les Emirs')),
        body: Center(child: Text('Erreur: $error')),
      );
    }
    if (data == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final categories = (data!['categories'] as List).cast<Map<String, dynamic>>();

    final Widget typesSection = (showTypes && (activeGroup != null) && activeGroup != 'services')
        ? Flexible(
            fit: FlexFit.loose,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, .05), end: Offset.zero).animate(a), child: c)),
                child: SingleChildScrollView(
                  key: ValueKey("types-${activeGroup}-${activeType == '__VIN__'}"),
                  child: Column(
                    children: [
                      if (activeType == '__VIN__') ...[
                        for (final wt in const ['Vin blanc','Vin rosé','Vin rouge','Vin français']) Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  activeWineSubType = wt;
                                  showTypes = false;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Center(child: Text(_pluralTypeLabel(wt))),
                            ),
                          ),
                        ),
                      ] else ...[
                        for (final t in _typesForActiveGroup()) Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () {
                                setState(() {
                                  activeType = t;
                                  activeWineSubType = null;
                                  showTypes = (t == '__VIN__');
                                });
                              },
                              child: Center(child: Text(t == '__VIN__' ? 'Vins' : _pluralTypeLabel(t))),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          )
        : const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('${Strings.t('menu')} - Les Emirs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: _openLangSheet,
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.pushNamed(context, '/history'),
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CartPage()),
            ),
          ),
        ],
      ),
      body: Column(children: [
        // Onglets de groupes
        SizedBox(
          height: 54,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final g in _orderedGroups()) Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: ChoiceChip(
                    key: ValueKey('tab-$g-${g==activeGroup}'),
                  label: Text(_labelForGroup(g)),
                  selected: g == activeGroup,
                  onSelected: (_) {
                    if (g == activeGroup) {
                      setState(() {
                        showTypes = !showTypes;
                        if (showTypes) { activeType = null; activeWineSubType = null; }
                      });
                    } else {
                      setState(() {
                        activeGroup = g;
                        showTypes = true; // l'utilisateur choisit un type
                        activeType = null;
                        activeWineSubType = null;
                      });
                    }
                  },
                  ),
                ),
              )
            ],
          ),
        ),
        // Sous-catégories (types)
        typesSection,
        const Divider(height: 1),
        // Contenu: soit Services, soit articles filtrés
        (
          (activeGroup == 'services')
            ? Expanded(child: _buildServices())
            : (!showTypes && (activeType != null))
              ? Expanded(
                  child: Builder(builder: (context) {
                    final flat = _itemsForActiveType();
                    // 🎯 Regrouper les articles similaires (Coca/Fanta/etc.)
                    final grouped = _groupSimilarItems(flat);
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
                      child: ListView.separated(
                        key: ValueKey('list-${activeGroup}-${activeType}-${activeWineSubType}-${grouped.length}'),
                        itemCount: grouped.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) => _buildLineItem(grouped[i]),
                      ),
                    );
                  }),
                )
              : const SizedBox.shrink()
        ),
      ]),
      // Barre mobile avec total + accès panier
      bottomNavigationBar: ValueListenableBuilder(
        valueListenable: cart.items,
        builder: (context, _, __) {
          final count = cart.items.value.fold<int>(0, (s, e) => s + e.quantity);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black12)]),
            child: Row(children: [
              Text(Strings.t('total'), style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (c, anim) => ScaleTransition(scale: anim, child: c),
                child: Text('${cart.total.toStringAsFixed(2)} TND', key: ValueKey(cart.total.toStringAsFixed(2)), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              Stack(
                alignment: Alignment.center,
                children: [
              ElevatedButton.icon(
                    key: _cartButtonKey,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartPage())),
                icon: const Icon(Icons.shopping_cart_outlined),
                    label: Text(Strings.t('cart')),
                  ),
                  Positioned(
                    right: 6,
                    top: 4,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 200),
                      scale: count > 0 ? 1 : 0.0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Theme.of(context).colorScheme.error, borderRadius: BorderRadius.circular(10)),
                        child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  )
                ],
              ),
            ]),
          );
        },
      ),
    );
  }

  List<String> _orderedGroups() {
    final keys = groupToCategories.keys.toSet();
    final ordered = <String>[];
    if (keys.remove('drinks')) ordered.add('drinks');
    if (keys.remove('spirits')) ordered.add('spirits');
    if (keys.remove('food')) ordered.add('food');
    // Insérer Services juste après Plats
    ordered.add('services');
    ordered.addAll(keys);
    return ordered;
  }

  Future<void> _openLangSheet() async {
    final langs = const [
      ('fr','Français'),
      ('ar','العربية'),
      ('en','English'),
      ('de','Deutsch'),
    ];
    await showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              const Text('Langue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...langs.map((e) => ListTile(
                title: Text(e.$2),
                trailing: ValueListenableBuilder(
                  valueListenable: LangService.instance.current,
                  builder: (context, v, _) => v == e.$1 ? const Icon(Icons.check) : const SizedBox.shrink(),
                ),
                onTap: () async {
                  final was = LangService.instance.lang;
                  await LangService.instance.set(e.$1);
                  if (mounted) Navigator.pop(context);
                  // recharger le menu dans la langue
                  if (mounted) {
                    // Si on change réellement de langue, forcer un refresh (bypass cache)
                    await ApiClient.dio.get('/menu/les-emirs', queryParameters: {'lng': LangService.instance.lang, 'refresh': '1'});
                    _load();
                  }
                },
              )),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  

  Iterable<Map<String, dynamic>> _categoriesForActiveGroup(List<Map<String, dynamic>> all) sync* {
    final g = activeGroup;
    if (g == null) return;
    for (final c in (groupToCategories[g] ?? const [])) {
      final items = (c['items'] as List).cast<Map<String, dynamic>>();
      final filtered = activeType == null ? items : items.where((it) => (it['type'] as String?) == activeType).toList();
      if (filtered.isEmpty) continue;
      yield {
        ...c,
        'items': filtered,
      };
    }
  }

  // Services inline (demande de quantité/type)
  Widget _buildServices() {
    final entries = [
      {'id': 'clear', 'label': Strings.t('service_clear')},
      {'id': 'cutlery', 'label': Strings.t('service_cutlery')},
      {'id': 'glasses', 'label': Strings.t('service_glasses')},
      {'id': 'ice', 'label': Strings.t('service_ice')},
      {'id': 'cleaning', 'label': Strings.t('service_cleaning')}
    ];
    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final e = entries[i];
        return ListTile(
          title: Text(e['label'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: ElevatedButton(
            onPressed: () => _handleService(e['id'] as String, e['label'] as String),
            child: Text(Strings.t('call')),
          ),
        );
      },
    );
  }

  Future<void> _handleService(String type, String label) async {
    // Envoi immédiat pour clear/cleaning/ice (pas de quantité requise)
    if (type == 'clear' || type == 'cleaning' || type == 'ice') {
      await _sendService(type, 1, null);
      return;
    }
    // Bottom sheet pour cutlery / glasses
    await _openServiceBottomSheet(type: type, title: label);
  }

  Future<void> _openServiceBottomSheet({required String type, required String title}) async {
    final List<String> glassTypes = const ['Vin','Whisky','Eau','Vodka','Champagne'];
    bool askGlass = type == 'glasses';
    bool askQty = type == 'glasses' || type == 'cutlery';
    int qty = 1;
    String? subType;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: StatefulBuilder(builder: (context, setSheet) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                    IconButton(onPressed: ()=> Navigator.pop(context), icon: const Icon(Icons.close)),
                  ]),
                  if (askGlass) Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 12),
                    child: Wrap(spacing: 8, children: [
                      for (final g in glassTypes)
                        ChoiceChip(
                          label: Text(g),
                          selected: subType == g,
                          onSelected: (_) => setSheet((){ subType = g; }),
                        )
                    ]),
                  ),
                  if (askQty) Row(children: [
                    const Text('Quantité', style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    IconButton(onPressed: (){ if (qty>1) setSheet(()=> qty--); }, icon: const Icon(Icons.remove_circle_outline, size: 28)),
                    Text('$qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: (){ setSheet(()=> qty++); }, icon: const Icon(Icons.add_circle_outline, size: 28)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: OutlinedButton(onPressed: ()=> Navigator.pop(context), child: const Text('Annuler'))),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton(onPressed: (){
                      Navigator.pop(context);
                      _sendService(type, qty, subType);
                    }, child: const Text('Envoyer'))),
                  ])
                ],
              ),
            );
          }),
        );
      },
    );
  }

  Future<void> _sendService(String type, int quantity, String? subType) async {
    try {
      final payload = {
        'table': tableCode ?? 'A3',
        'type': type,
        'quantity': quantity,
        if (subType != null) 'subType': subType,
      };
      await ApiClient.dio.post('/service-requests', data: payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demande envoyée')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Widget _buildCategoryCard(Map<String, dynamic> c) {
    final items = (c['items'] as List).cast<Map<String, dynamic>>();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ExpansionTile(
        title: Text(c['name'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        children: [
          for (final it in items) _buildLineItem(it)
        ],
      ),
    );
  }

  // Agrège tous les items correspondant au type actif pour une liste plate
  List<Map<String, dynamic>> _itemsForActiveType() {
    final g = activeGroup;
    final t = activeType;
    if (g == null || t == null) return const [];
    final result = <Map<String, dynamic>>[];
    for (final c in (groupToCategories[g] ?? const [])) {
      final items = (c['items'] as List).cast<Map<String, dynamic>>();
      for (final it in items) {
        final itType = (it['type'] as String?) ?? '';
        if (t == '__VIN__') {
          if (activeWineSubType != null) {
            if (itType == activeWineSubType) result.add(it);
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

  // 🎯 REGROUPEMENT INTELLIGENT des articles similaires
  // Regroupe les articles du même prix/type en un seul item virtuel avec variantes
  List<Map<String, dynamic>> _groupSimilarItems(List<Map<String, dynamic>> items) {
    final grouped = <Map<String, dynamic>>[];
    final processed = <int>{};
    
    for (int i = 0; i < items.length; i++) {
      if (processed.contains(i)) continue;
      
      final item = items[i];
      final price = (item['price'] as num).toDouble();
      final type = item['type'] as String?;
      final name = item['name'] as String? ?? '';
      
      // Chercher des articles similaires (même prix, même type, pas d'options déjà dans le nom)
      final variants = <Map<String, dynamic>>[item];
      processed.add(i);
      
      // Grouper seulement si c'est des sodas/jus simples (Coca, Fanta, etc.)
      final isSimpleDrink = _isSimpleDrink(name);
      
      if (isSimpleDrink) {
        for (int j = i + 1; j < items.length; j++) {
          if (processed.contains(j)) continue;
          
          final other = items[j];
          final otherPrice = (other['price'] as num).toDouble();
          final otherType = other['type'] as String?;
          final otherName = other['name'] as String? ?? '';
          
          // Même prix, même type, nom simple
          if (otherPrice == price && otherType == type && _isSimpleDrink(otherName)) {
            variants.add(other);
            processed.add(j);
          }
        }
      }
      
      // Si plusieurs variantes, créer un item groupé
      if (variants.length > 1) {
        final variantNames = variants.map((v) => v['name'] as String).toList();
        grouped.add({
          ...item,
          'name': variantNames.join(' / '),
          '_isGroup': true,
          '_variants': variants,
        });
      } else {
        grouped.add(item);
      }
    }
    
    return grouped;
  }

  // Détecte si c'est un nom simple (pas d'options ni de description longue)
  bool _isSimpleDrink(String name) {
    // Exclure les noms avec parenthèses, virgules, "ou", descriptions longues
    if (name.contains('(') || name.contains(',') || name.toLowerCase().contains(' ou ')) return false;
    if (name.split(' ').length > 3) return false; // Max 3 mots
    
    // Liste blanche de sodas/jus simples
    final simpleDrinks = ['coca', 'fanta', 'sprite', 'boga', 'schweppes', 'jus', 'zéro', 'tonic'];
    final nameLower = name.toLowerCase();
    return simpleDrinks.any((drink) => nameLower.contains(drink));
  }

  // Affiche une boîte de dialogue centrée avec une liste verticale d'options
  Future<String?> _pickFromList(String title, List<String> options) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (title.isNotEmpty) Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    if (title.isNotEmpty) const SizedBox(height: 12),
                    ...options.map((o) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, o),
                          style: ElevatedButton.styleFrom(textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          child: Text(o),
                        ),
                      ),
                    )),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLineItem(Map<String, dynamic> it) {
    final isGroup = it['_isGroup'] == true;
    final variants = isGroup ? (it['_variants'] as List<Map<String, dynamic>>?) : null;

    // Disponibilité: pour un groupe, on autorise seulement les variantes disponibles
    final availableVariants = variants?.where((v) => (v['available'] ?? true) == true).toList() ?? const [];
    final isAvailable = isGroup ? availableVariants.isNotEmpty : ((it['available'] ?? true) == true);
    final displayPrice = (){
      if (isGroup) {
        if (availableVariants.isNotEmpty) {
          final p = (availableVariants.first['price'] as num).toDouble();
          return '${p.toStringAsFixed(2)} TND';
        }
        return 'Indisponible';
      } else {
        final price = ((it['price'] as num).toDouble());
        return isAvailable ? '${price.toStringAsFixed(2)} TND' : 'Indisponible';
      }
    }();

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isAvailable ? 1.0 : 0.6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6),
        child: Row(children: [
          Expanded(
            child: Text(
              it['name'] as String,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isAvailable ? Colors.black : Colors.grey, decoration: isAvailable ? null : TextDecoration.lineThrough),
            ),
          ),
          SizedBox(
            width: 140,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                displayPrice,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isAvailable ? Colors.black : Colors.orange),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Builder(builder: (btnCtx) {
            return ElevatedButton(
              onPressed: !isAvailable ? null : () async {
                if (isGroup) {
                  final variantNames = availableVariants.map((v) => v['name'] as String).toList();
                  final chosen = await _pickFromList('Choisir', variantNames);
                  if (chosen == null) return;
                  final selectedItem = availableVariants.firstWhere((v) => v['name'] == chosen);
                  final ok = await _debouncedAdd(selectedItem);
                  if (ok) { try { HapticFeedback.selectionClick(); } catch (_) {} _animateAddToCartFrom(btnCtx); }
                } else {
                  final ok = await _debouncedAdd(it);
                  if (ok) { try { HapticFeedback.selectionClick(); } catch (_) {} _animateAddToCartFrom(btnCtx); }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isAvailable ? null : Colors.grey.shade300,
                foregroundColor: isAvailable ? null : Colors.grey.shade600,
              ),
              child: const Text('Ajouter'),
            );
          })
        ]),
      ),
    );
  }

  bool _adding = false;
  int? _justAddedItemId;
  Future<bool> _debouncedAdd(Map<String, dynamic> it) async {
    if (_adding) return false; // anti double-tap
    _adding = true;
    try {
      final ok = await _addItemWithOptions(it);
      return ok;
    } finally {
      await Future.delayed(const Duration(milliseconds: 250));
      _adding = false;
    }
  }

  // Animation: petit cercle qui vole du bouton vers l'icône panier
  void _animateAddToCartFrom(BuildContext startCtx) {
    final overlay = Overlay.of(context);
    if (overlay == null) return;
    final startBox = startCtx.findRenderObject() as RenderBox?;
    final cartBox = _cartButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (startBox == null || cartBox == null) return;
    final start = startBox.localToGlobal(startBox.size.center(Offset.zero));
    final end = cartBox.localToGlobal(cartBox.size.center(Offset.zero));
    OverlayEntry? entry;
    entry = OverlayEntry(builder: (_) {
      return _FlyDot(start: start, end: end, onEnd: () => entry?.remove());
    });
    overlay.insert(entry);
  }

  Future<bool> _addItemWithOptions(Map<String, dynamic> it) async {
    final baseName = it['name'] as String;
    final price = ((it['price'] as num).toDouble());
    String nameToAdd = baseName;

    // Derivation d'options strictement depuis le texte (séparateur '/')
    final derived = _deriveOptionsFromName(baseName);
    if (derived.options.isNotEmpty) {
      String? choice = await _pickFromList(derived.base, derived.options);
      if (choice == null) return false;
      nameToAdd = derived.base.isEmpty ? choice : '${derived.base} $choice';
    } else {
      // Si pas d'options dérivées mais c'est une viande (détectée via type original du menu), proposer la cuisson
      final t = (it['type'] as String?)?.toLowerCase() ?? '';
      final ot = (it['originalType'] as String?)?.toLowerCase() ?? '';
      if (t.contains('viande') || ot.contains('viande')) {
        final cuissons = ['Bleu','Saignant','À point','Bien cuit'];
        String? cuisson = await _pickFromList('Cuisson de la viande', cuissons);
        if (cuisson == null) return false;
        nameToAdd = '$baseName (cuisson: $cuisson)';
      }
    }

            await CartService.instance.addItem(
              id: (it['id'] as num).toInt(),
      name: nameToAdd,
              price: price,
            );
            if (context.mounted) {
      final top = MediaQuery.of(context).padding.top + 12;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(12, top, 12, 0),
          duration: const Duration(milliseconds: 1200),
          backgroundColor: Colors.teal,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: _AddedSnack(name: nameToAdd),
        ),
      );
    }
    return true;
  }

  OptionsResult _deriveOptionsFromName(String name) {
    String base = '';
    List<String> options = [];
    final hasParen = name.contains('(') && name.contains(')');
    if (hasParen) {
      final start = name.indexOf('(');
      final end = name.indexOf(')', start + 1);
      if (end > start) {
        final inside = name.substring(start + 1, end);
        if (inside.contains('/')) {
          base = name.substring(0, start).trim();
          options = inside.split('/').map((s) => s.replaceAll(RegExp(r'[\s\u00A0]+'), ' ').trim()).where((s)=> s.isNotEmpty).toList();
        }
      }
    }
    if (options.isEmpty && name.contains('/')) {
      final parts = name.split('/').map((s) => s.replaceAll(RegExp(r'[\s\u00A0]+'), ' ').trim()).where((s)=> s.isNotEmpty).toList();
      if (parts.length > 1) {
        base = '';
        options = parts;
      }
    }
    return OptionsResult(base: base, options: options);
  }

  String _shortName(String s) {
    if (s.length <= 18) return s;
    return s.substring(0, 16) + '…';
  }
}

class _FlyDot extends StatefulWidget {
  final Offset start;
  final Offset end;
  final VoidCallback onEnd;
  const _FlyDot({required this.start, required this.end, required this.onEnd});
  @override
  State<_FlyDot> createState() => _FlyDotState();
}

class _FlyDotState extends State<_FlyDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..addStatusListener((s){ if (s==AnimationStatus.completed) widget.onEnd(); });
  @override
  void initState(){ super.initState(); _c.forward(); }
  @override
  void dispose(){ _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final tweenX = Tween<double>(begin: widget.start.dx, end: widget.end.dx).chain(CurveTween(curve: Curves.easeInOut));
    final tweenY = Tween<double>(begin: widget.start.dy, end: widget.end.dy).chain(CurveTween(curve: Curves.easeInOut));
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final x = tweenX.evaluate(_c);
        final y = tweenY.evaluate(_c);
        return Positioned(
          left: x - 6,
          top: y - 6,
          child: IgnorePointer(
            ignoring: true,
            child: Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.teal, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)])),
          ),
        );
      },
    );
  }
}

class _AddedSnack extends StatelessWidget {
  final String name;
  const _AddedSnack({required this.name});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.shopping_cart, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Ajouté au panier: ${_shortDisplay(name)}',
            style: const TextStyle(color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _shortDisplay(String s) {
    if (s.length <= 26) return s;
    return s.substring(0, 24) + '…';
  }
}


