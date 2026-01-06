import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../core/api_client.dart';

class AdminMenuEditorPage extends StatefulWidget {
  final String restaurantId;
  final String? openQuick; // 'hidden' | 'unavailable'
  const AdminMenuEditorPage({super.key, required this.restaurantId, this.openQuick});
  @override
  State<AdminMenuEditorPage> createState() => _AdminMenuEditorPageState();
}

class _AdminMenuEditorPageState extends State<AdminMenuEditorPage> {
  Map<String, dynamic>? menu;
  bool loading = true;
  String? error;
  String searchQuery = '';
  String? selectedGroup; // 'drinks', 'spirits', 'food'
  String? selectedType; // 'Boisson froide', 'Vin blanc', etc.
  String? selectedWineSubType; // Pour les vins regroupés
  io.Socket? socket;

  @override
  void initState() {
    super.initState();
    _loadMenu();
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
      print('[admin] Socket event: menu updated');
      // Recharger silencieusement en gardant la navigation
      _loadMenu(preserveNavigation: true);
    });
    
    s.connect();
  }

  Future<void> _loadMenu({bool preserveNavigation = false}) async {
    if (!preserveNavigation) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final res = await ApiClient.dio.get('/api/admin/menu/${widget.restaurantId}');
      setState(() {
        menu = res.data as Map<String, dynamic>;
        if (!preserveNavigation) loading = false;
      });
      // Ouvrir éventuellement une vue rapide (une seule fois)
      if (widget.openQuick != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || menu == null) return;
          final categories = (menu?['categories'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          final unavailableItems = <Map<String, dynamic>>[];
          final hiddenItems = <Map<String, dynamic>>[];
          for (final cat in categories) {
            for (final item in ((cat['items'] as List?) ?? [])) {
              final it = item as Map<String, dynamic>;
              if (it['available'] == false) unavailableItems.add({...it, '_category': cat['name']});
              if (it['hidden'] == true) hiddenItems.add({...it, '_category': cat['name']});
            }
          }
          if (widget.openQuick == 'unavailable') {
            _showUnavailableItems(unavailableItems);
          } else if (widget.openQuick == 'hidden') {
            _showHiddenItems(hiddenItems);
          }
        });
      }
    } on DioException catch (e) {
      setState(() {
        error = e.response?.data['error'] ?? e.message;
        if (!preserveNavigation) loading = false;
      });
    }
  }

  Future<void> _addCategory() async {
    final nameCtrl = TextEditingController();
    String group = 'food';
    
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, setDialog) {
        return AlertDialog(
          title: const Text('Nouvelle Catégorie'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom de la catégorie')),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: group,
                decoration: const InputDecoration(labelText: 'Groupe'),
                items: const [
                  DropdownMenuItem(value: 'food', child: Text('Plats (food)')),
                  DropdownMenuItem(value: 'drinks', child: Text('Boissons (drinks)')),
                  DropdownMenuItem(value: 'spirits', child: Text('Alcools (spirits)')),
                ],
                onChanged: (v) => setDialog(() => group = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                try {
                  await ApiClient.dio.post('/api/admin/menu/${widget.restaurantId}/categories', data: {'name': name, 'group': group});
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        );
      }),
    );
    if (ok == true) _loadMenu();
  }

  Future<void> _deleteCategory(String categoryName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la catégorie?'),
        content: Text('Tous les articles de "$categoryName" seront supprimés.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiClient.dio.delete('/api/admin/menu/${widget.restaurantId}/categories/${Uri.encodeComponent(categoryName)}');
      _loadMenu();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _addItem() async {
    // Utiliser le type actuel (Boisson froide, Vin blanc, etc.)
    final currentType = selectedType == '__VIN__' ? selectedWineSubType : selectedType;
    if (currentType == null) return;
    
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final typeCtrl = TextEditingController(text: currentType);
    
    // Trouver la catégorie correspondante
    final categories = (menu?['categories'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    String? categoryName;
    for (final cat in categories) {
      if ((cat['group'] ?? 'food') == selectedGroup) {
        categoryName = cat['name'] as String?;
        break;
      }
    }
    if (categoryName == null) return;
    
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Nouvel Article - $currentType'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom (ex: Eau Pétillante, Monster Energy)')),
              const SizedBox(height: 12),
              TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Prix'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextField(controller: typeCtrl, decoration: InputDecoration(labelText: 'Type', hintText: currentType), enabled: false),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final priceStr = priceCtrl.text.trim();
              if (name.isEmpty || priceStr.isEmpty) return;
              final price = double.tryParse(priceStr);
              if (price == null) return;
              try {
                await ApiClient.dio.post('/api/admin/menu/${widget.restaurantId}/items', data: {
                  'categoryName': categoryName,
                  'name': name,
                  'price': price,
                  'type': currentType, // Utiliser le type actuel (Boisson froide, etc.)
                });
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    if (ok == true) _loadMenu(preserveNavigation: true);
  }

  Future<void> _editItem(Map<String, dynamic> item) async {
    final nameCtrl = TextEditingController(text: item['name']);
    final priceCtrl = TextEditingController(text: item['price'].toString());
    final typeCtrl = TextEditingController(text: item['type']);
    bool available = item['available'] ?? true;
    
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, setDialog) {
        return AlertDialog(
          title: const Text('Modifier Article'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom')),
                const SizedBox(height: 12),
                TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Prix'), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextField(controller: typeCtrl, decoration: const InputDecoration(labelText: 'Type')),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Disponible'),
                  value: available,
                  onChanged: (v) => setDialog(() => available = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final priceStr = priceCtrl.text.trim();
                final type = typeCtrl.text.trim();
                if (name.isEmpty || priceStr.isEmpty) return;
                final price = double.tryParse(priceStr);
                if (price == null) return;
                try {
                  await ApiClient.dio.patch('/api/admin/menu/${widget.restaurantId}/items/${item['id']}', data: {
                    'name': name,
                    'price': price,
                    'type': type,
                    'available': available,
                  });
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      }),
    );
    if (ok == true) _loadMenu();
  }

  Future<void> _deleteItem(int itemId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer l\'article?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiClient.dio.delete('/api/admin/menu/${widget.restaurantId}/items/$itemId');
      _loadMenu();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _toggleAvailability(Map<String, dynamic> item) async {
    final newAvailability = !(item['available'] ?? true);
    try {
      await ApiClient.dio.patch('/api/admin/menu/${widget.restaurantId}/items/${item['id']}', data: {
        'available': newAvailability,
      });
      // Mise à jour locale immédiate AVANT le reload
      setState(() {
        item['available'] = newAvailability;
      });
      // Reload en arrière-plan pour synchroniser
      _loadMenu(preserveNavigation: true);
      // Notification
      if (mounted) {
        try { HapticFeedback.selectionClick(); } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(newAvailability ? '✅ Disponible' : '⚠️ Indisponible'),
          duration: const Duration(milliseconds: 900),
          backgroundColor: newAvailability ? Colors.green : Colors.orange,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  void _showUnavailableItems(List<Map<String, dynamic>> items) {
    // Construire une liste locale une seule fois pour éviter le "double clic"
    var currentUnavailable = List<Map<String, dynamic>>.from(items);
    final removing = <int>{};
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.visibility_off, color: Colors.orange),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text('Articles masqués (${currentUnavailable.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: currentUnavailable.isEmpty
                          ? const Center(child: Text('✅ Tous les articles sont disponibles !', style: TextStyle(fontSize: 16, color: Colors.green)))
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: currentUnavailable.length,
                              itemBuilder: (_, i) {
                                final item = currentUnavailable[i];
                                final price = (item['price'] as num?)?.toDouble() ?? 0;
                                final id = (item['id'] as num).toInt();
                                final isRemoving = removing.contains(id);
                                return Dismissible(
                                  key: ValueKey('unavail-${item['id']}'),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    color: Colors.green,
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: const Icon(Icons.play_arrow, color: Colors.white),
                                  ),
                                  confirmDismiss: (_) async {
                                    await _toggleAvailability(item);
                                    currentUnavailable = currentUnavailable
                                        .where((e) => e['id'] != item['id'])
                                        .toList();
                                    if (mounted) setModalState(() {});
                                    return true;
                                  },
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 160),
                                    opacity: isRemoving ? 0.0 : 1.0,
                                    child: isRemoving
                                        ? const SizedBox.shrink()
                                        : ListTile(
                                            leading: const Icon(
                                              Icons.report_problem,
                                              color: Colors.orange,
                                            ),
                                            title: Text(
                                              item['name'] ?? '',
                                              style: const TextStyle(
                                                decoration:
                                                    TextDecoration.lineThrough,
                                              ),
                                            ),
                                            subtitle: Text(
                                              '${price.toStringAsFixed(2)} TND • ${item['type']} • ${item['_category']}',
                                            ),
                                            trailing: ElevatedButton.icon(
                                              onPressed: () async {
                                                removing.add(id);
                                                setModalState(() {});
                                                await Future.delayed(
                                                    const Duration(
                                                        milliseconds: 160));
                                                await _toggleAvailability(item);
                                                currentUnavailable =
                                                    currentUnavailable
                                                        .where((e) =>
                                                            e['id'] != id)
                                                        .toList();
                                                if (mounted)
                                                  setModalState(() {});
                                              },
                                              icon: const Icon(
                                                Icons.play_arrow,
                                                size: 18,
                                              ),
                                              label:
                                                  const Text('Rendre dispo'),
                                              style:
                                                  ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.green,
                                              ),
                                            ),
                                          ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showHiddenItems(List<Map<String, dynamic>> items) {
    var currentHidden = List<Map<String, dynamic>>.from(items);
    final removing = <int>{};
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Column(children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                    child: Row(children: [
                      const Icon(Icons.visibility_off),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Produits masqués (${currentHidden.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ]),
                  ),
                  Expanded(
                    child: currentHidden.isEmpty
                        ? const Center(child: Text('Aucun produit masqué'))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: currentHidden.length,
                              itemBuilder: (_, i) {
                              final item = currentHidden[i];
                                final id = (item['id'] as num).toInt();
                                final isRemoving = removing.contains(id);
                              return Dismissible(
                                key: ValueKey('hidden-${item['id']}'),
                                direction: DismissDirection.endToStart,
                                background: Container(color: Colors.blueGrey, alignment: Alignment.centerRight, padding: const EdgeInsets.symmetric(horizontal: 16), child: const Icon(Icons.visibility, color: Colors.white)),
                                confirmDismiss: (_) async {
                                  await _toggleHidden(item);
                                  currentHidden = currentHidden.where((e) => e['id'] != item['id']).toList();
                                  if (mounted) setModalState(() {});
                                  return true;
                                },
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 160),
                                  opacity: isRemoving ? 0.0 : 1.0,
                                  child: isRemoving ? const SizedBox.shrink() : ListTile(
                                  leading: const Icon(Icons.visibility_off, color: Colors.blueGrey),
                                  title: Text(item['name'] ?? ''),
                                  subtitle: Text('${item['type']} • ${item['_category']}'),
                                  trailing: ElevatedButton.icon(
                                    onPressed: () async {
                                      removing.add(id);
                                      setModalState(() {});
                                      await Future.delayed(const Duration(milliseconds: 160));
                                      await _toggleHidden(item);
                                      currentHidden = currentHidden.where((e) => e['id'] != id).toList();
                                      if (mounted) setModalState(() {});
                                    },
                                    icon: const Icon(Icons.visibility, size: 18),
                                    label: const Text('Afficher'),
                                  ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ]);
              },
            );
          },
        );
      },
    );
  }

  Future<void> _toggleHidden(Map<String, dynamic> item) async {
    final newHidden = !(item['hidden'] == true);
    try {
      await ApiClient.dio.patch('/api/admin/menu/${widget.restaurantId}/items/${item['id']}', data: {'hidden': newHidden});
      setState(() { item['hidden'] = newHidden; });
      try { HapticFeedback.selectionClick(); } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(newHidden ? '👁️ Masqué du client' : '👁️‍🗨️ Affiché au client'),
          duration: const Duration(milliseconds: 900),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  // Regrouper les items comme dans le client (Coca/Fanta groupés)
  List<Map<String, dynamic>> _groupSimilarItems(List<Map<String, dynamic>> items) {
    final grouped = <Map<String, dynamic>>[];
    final processed = <int>{};
    
    for (int i = 0; i < items.length; i++) {
      if (processed.contains(i)) continue;
      
      final item = items[i];
      final price = (item['price'] as num).toDouble();
      final type = item['type'] as String?;
      final name = item['name'] as String? ?? '';
      
      final variants = <Map<String, dynamic>>[item];
      processed.add(i);
      
      final isSimpleDrink = _isSimpleDrink(name);
      
      if (isSimpleDrink) {
        for (int j = i + 1; j < items.length; j++) {
          if (processed.contains(j)) continue;
          
          final other = items[j];
          final otherPrice = (other['price'] as num).toDouble();
          final otherType = other['type'] as String?;
          final otherName = other['name'] as String? ?? '';
          
          if (otherPrice == price && otherType == type && _isSimpleDrink(otherName)) {
            variants.add(other);
            processed.add(j);
          }
        }
      }
      
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

  bool _isSimpleDrink(String name) {
    if (name.contains('(') || name.contains(',') || name.toLowerCase().contains(' ou ')) return false;
    if (name.split(' ').length > 3) return false;
    
    final simpleDrinks = ['coca', 'fanta', 'sprite', 'boga', 'schweppes', 'jus', 'zéro', 'tonic'];
    final nameLower = name.toLowerCase();
    return simpleDrinks.any((drink) => nameLower.contains(drink));
  }

  // Extraire les types distincts pour un groupe (comme dans le client)
  List<String> _typesForGroup(String group) {
    final categories = (menu?['categories'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final seen = <String>{};
    final ordered = <String>[];
    
    for (final cat in categories) {
      if ((cat['group'] ?? 'food') != group) continue;
      
      for (final item in ((cat['items'] as List?) ?? [])) {
        final t = (item as Map)['type'] as String?;
        if (t != null && t.isNotEmpty && !seen.contains(t)) {
          seen.add(t);
          ordered.add(t);
        }
      }
    }
    
    // Regrouper les vins (comme dans le client)
    final isWineType = (String x) => x.toLowerCase().startsWith('vin ');
    final result = <String>[];
    bool vinsAdded = false;
    for (final t in ordered) {
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

  // Obtenir les items pour un type spécifique (groupés)
  List<Map<String, dynamic>> _itemsForType(String group, String type) {
    final categories = (menu?['categories'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final result = <Map<String, dynamic>>[];
    
    for (final cat in categories) {
      if ((cat['group'] ?? 'food') != group) continue;
      
      final items = (cat['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final it in items) {
        final itType = (it['type'] as String?) ?? '';
        
        if (type == '__VIN__') {
          if (selectedWineSubType != null) {
            if (itType == selectedWineSubType) result.add(it);
          } else {
            if (itType.toLowerCase().startsWith('vin ')) result.add(it);
          }
        } else {
          if (itType == type) result.add(it);
        }
      }
    }
    
    return _groupSimilarItems(result);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (error != null) return Scaffold(body: Center(child: Text('Erreur: $error')));

    // Compter indisponibles et masqués (hidden)
    final categories = (menu?['categories'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    int unavailableCount = 0;
    int hiddenCount = 0;
    final unavailableItems = <Map<String, dynamic>>[];
    final hiddenItems = <Map<String, dynamic>>[];
    for (final cat in categories) {
      for (final item in ((cat['items'] as List?) ?? [])) {
        final it = item as Map<String, dynamic>;
        if (it['available'] == false) {
          unavailableCount++;
          unavailableItems.add({...it, '_category': cat['name']});
        }
        if (it['hidden'] == true) {
          hiddenCount++;
          hiddenItems.add({...it, '_category': cat['name']});
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(menu?['restaurant']?['name'] ?? widget.restaurantId),
        actions: [
          if (selectedType != null || selectedGroup != null)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() {
                if (selectedWineSubType != null) {
                  selectedWineSubType = null;
                } else if (selectedType != null) {
                  selectedType = null;
                } else {
                  selectedGroup = null;
                }
              }),
              tooltip: 'Retour',
            ),
          // Badge MASQUÉS (œil barré)
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.visibility_off),
                onPressed: () => _showHiddenItems(hiddenItems),
                tooltip: 'Produits masqués',
              ),
              if (hiddenCount > 0) Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.blueGrey, shape: BoxShape.circle),
                  child: Text('$hiddenCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          // Badge INDISPONIBLES (triangle warning)
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.report_problem),
                onPressed: () => _showUnavailableItems(unavailableItems),
                tooltip: 'Produits indisponibles',
              ),
              if (unavailableCount > 0) Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                  child: Text('$unavailableCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadMenu),
        ],
      ),
      body: Column(
        children: [
          // Raccourcis supprimés pour éviter la duplication avec les icônes AppBar
          const SizedBox.shrink(),
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un article...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
              onChanged: (v) => setState(() => searchQuery = v),
            ),
          ),
          // Fil d'Ariane (navigation)
          if (selectedGroup != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      selectedGroup = null;
                      selectedType = null;
                      selectedWineSubType = null;
                    }),
                    child: const Text('Accueil'),
                  ),
                  const Text(' > '),
                  Text(_getGroupLabel(selectedGroup!), style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (selectedType != null) ...[
                    const Text(' > '),
                    Text(selectedType == '__VIN__' ? 'Vins' : selectedType!, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                  if (selectedWineSubType != null) ...[
                    const Text(' > '),
                    Text(selectedWineSubType!, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
          ],
          // Onglets GROUPES (comme le client)
          if (selectedGroup == null) ...[
            SizedBox(
              height: 54,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  _buildGroupChip('🥤 Boissons', 'drinks'),
                  _buildGroupChip('🍷 Spiritueux', 'spirits'),
                  _buildGroupChip('🍽️ Plats', 'food'),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
          // Onglets TYPES (Boisson froide, Vin blanc, etc.)
          if (selectedGroup != null && selectedType == null) ...[
            Expanded(
              child: _buildTypesList(),
            ),
          ],
          // Liste des items si un type est sélectionné
          if (selectedType != null) ...[
            if (selectedType == '__VIN__' && selectedWineSubType == null) ...[
              Expanded(child: _buildWineSubTypes()),
            ] else ...[
              Expanded(child: _buildItemsList()),
            ],
          ],
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  String _getGroupLabel(String group) {
    switch (group) {
      case 'drinks': return 'Boissons';
      case 'spirits': return 'Spiritueux';
      case 'food': return 'Plats';
      default: return group;
    }
  }

  Widget? _buildFAB() {
    // Si on est dans une liste d'articles (type sélectionné ou vin sous-type)
    final canAddItem = (selectedType != null && selectedType != '__VIN__') || 
                       (selectedType == '__VIN__' && selectedWineSubType != null);
    
    if (canAddItem) {
      return FloatingActionButton.extended(
        onPressed: _addItem,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter Article'),
      );
    } else if (selectedGroup == null) {
      return FloatingActionButton.extended(
        onPressed: _addCategory,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter Catégorie'),
      );
    }
    return null;
  }

  Widget _buildGroupChip(String label, String group) {
    final isSelected = selectedGroup == group;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() {
          if (selectedGroup == group) {
            selectedGroup = null;
            selectedType = null;
            selectedWineSubType = null;
          } else {
            selectedGroup = group;
            selectedType = null;
            selectedWineSubType = null;
          }
        }),
      ),
    );
  }

  Widget _buildTypesList() {
    final types = _typesForGroup(selectedGroup!);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: types.length,
      itemBuilder: (_, i) {
        final type = types[i];
        final displayName = type == '__VIN__' ? 'Vins' : type;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: () => setState(() {
                selectedType = type;
                if (type != '__VIN__') selectedWineSubType = null;
              }),
              style: OutlinedButton.styleFrom(
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Center(child: Text(displayName)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWineSubTypes() {
    final wineTypes = ['Vin blanc', 'Vin rosé', 'Vin rouge', 'Vin français'];
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: wineTypes.length,
      itemBuilder: (_, i) {
        final wineType = wineTypes[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: () => setState(() => selectedWineSubType = wineType),
              style: OutlinedButton.styleFrom(
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Center(child: Text(wineType)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemsList() {
    final type = selectedType == '__VIN__' ? selectedWineSubType! : selectedType!;
    final items = _itemsForType(selectedGroup!, type);
    
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96, top: 4),
      itemCount: items.length,
      itemBuilder: (_, i) => _buildItemTile(items[i]),
    );
  }

  Widget _buildItemTile(Map<String, dynamic> item) {
    final isGroup = item['_isGroup'] == true;
    final variants = isGroup ? (item['_variants'] as List<Map<String, dynamic>>?) : null;
    final price = (item['price'] as num).toDouble();
    
    if (isGroup && variants != null) {
      // Groupe d'articles (Coca/Fanta/Boga)
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: ExpansionTile(
          title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${price.toStringAsFixed(2)} ${menu?['restaurant']?['currency']} • ${variants.length} variantes'),
          children: variants.map((v) => _buildSingleItem(v, true)).toList(),
        ),
      );
    } else {
      // Article simple
      return _buildSingleItem(item, false);
    }
  }

  Widget _buildSingleItem(Map<String, dynamic> item, bool isVariant) {
    final isAvailable = item['available'] ?? true;
    final isHidden = item['hidden'] == true;
    final price = (item['price'] as num).toDouble();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      color: isHidden ? Colors.blueGrey.shade50 : (!isAvailable ? Colors.orange.shade50 : null),
      margin: isVariant ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        dense: isVariant,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(isHidden ? Icons.visibility : Icons.visibility_off, color: isHidden ? Colors.blueGrey : Colors.grey),
              tooltip: isHidden ? 'Afficher dans le menu' : 'Masquer du menu',
              onPressed: () => _toggleHidden(item),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Switch(
                key: ValueKey(isAvailable),
                value: isAvailable,
                onChanged: (_) => _toggleAvailability(item),
              ),
            ),
          ],
        ),
        title: InkWell(
          onTap: () => _editNameInline(item),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              item['name'],
              style: TextStyle(
                fontWeight: isVariant ? FontWeight.w500 : FontWeight.w600,
                color: (!isAvailable || isHidden) ? Colors.grey : Colors.black,
                decoration: (!isAvailable || isHidden) ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ),
        subtitle: InkWell(
          onTap: () => _editPriceInline(item),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(children: [
              if (isHidden) Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.blueGrey.shade200, borderRadius: BorderRadius.circular(10)), child: const Text('Masqué', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
              if (!isHidden && !isAvailable) Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(10)), child: const Text('Indisponible', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
              Flexible(
                child: Text(
                  '${price.toStringAsFixed(2)} ${menu?['restaurant']?['currency']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.edit, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  ' • ${item['type']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ]),
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
          onPressed: () => _deleteItem(item['id']),
          tooltip: 'Supprimer',
        ),
      ),
    );
  }

  Future<void> _editNameInline(Map<String, dynamic> item) async {
    final ctrl = TextEditingController(text: item['name']);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Modifier le nom'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: 'Nom de l\'article')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      try {
        await ApiClient.dio.patch('/api/admin/menu/${widget.restaurantId}/items/${item['id']}', data: {'name': ctrl.text.trim()});
        setState(() { item['name'] = ctrl.text.trim(); });
        try { HapticFeedback.mediumImpact(); } catch (_) {}
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _editPriceInline(Map<String, dynamic> item) async {
    final ctrl = TextEditingController(text: (item['price'] as num).toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Modifier le prix de ${item['name']}'),
        content: TextField(controller: ctrl, keyboardType: TextInputType.number, autofocus: true, decoration: const InputDecoration(labelText: 'Prix (TND)', suffixText: 'TND')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (ok == true) {
      final newPrice = double.tryParse(ctrl.text.trim());
      if (newPrice != null) {
        try {
          await ApiClient.dio.patch('/api/admin/menu/${widget.restaurantId}/items/${item['id']}', data: {'price': newPrice});
          setState(() { item['price'] = newPrice; });
          try { HapticFeedback.mediumImpact(); } catch (_) {}
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
        }
      }
    }
  }
}
