// 📦 Page Admin - Gestion du stock (inventaire) par restaurant
// Miroir fonctionnel de AdminMenuEditorPage : navigation Groupe → Type → (Vins) → liste articles ; [ - ] Stock [ + ] ou « Activer le suivi »
// Plan stock : STRUCTURE_POS, .cursorrules

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../core/api_client.dart';

class AdminInventoryPage extends StatefulWidget {
  final String restaurantId;
  final String? restaurantName;

  const AdminInventoryPage({
    super.key,
    required this.restaurantId,
    this.restaurantName,
  });

  @override
  State<AdminInventoryPage> createState() => _AdminInventoryPageState();
}

class _AdminInventoryPageState extends State<AdminInventoryPage> {
  Map<String, dynamic>? inventory;
  bool loading = true;
  String? error;
  String searchQuery = '';
  String? selectedGroup; // 'drinks', 'spirits'
  String? selectedType; // 'Boisson froide', 'Apéritif', '__VIN__', etc.
  String? selectedWineSubType; // 'Vin blanc', 'Vin rosé', etc.
  io.Socket? socket;
  final Set<int> _updatingItemIds = {};

  @override
  void initState() {
    super.initState();
    _loadInventory();
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
    s.on('inventory:updated', (_) {
      if (mounted) _loadInventory(preserveNavigation: true);
    });
    s.connect();
  }

  Future<void> _loadInventory({bool preserveNavigation = false}) async {
    if (!preserveNavigation) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final res = await ApiClient.dio.get('/api/admin/inventory/${widget.restaurantId}');
      if (mounted) {
        setState(() {
          inventory = res.data as Map<String, dynamic>;
          loading = false;
        });
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        if (mounted) {
          setState(() {
            inventory = null;
            loading = false;
            error = 'non_initialise';
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          error = e.response?.data?['error'] ?? e.message ?? 'Erreur chargement';
          loading = false;
        });
      }
    }
  }

  Future<void> _initFromMenu() async {
    setState(() => loading = true);
    try {
      await ApiClient.dio.post('/api/admin/inventory/${widget.restaurantId}/init', data: {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inventaire initialisé (tous les groupes boissons)'), backgroundColor: Colors.green),
        );
        _loadInventory();
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.data?['error'] ?? e.message ?? 'Erreur'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showHistory() async {
    try {
      final res = await ApiClient.dio.get('/api/admin/inventory/${widget.restaurantId}/history');
      final list = (res.data as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (!mounted) return;
      final items = (inventory?['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final itemIdToName = <int, String>{};
      for (final it in items) {
        final id = (it['itemId'] as num?)?.toInt();
        final name = it['name'] as String?;
        if (id != null && name != null) itemIdToName[id] = name;
      }
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _InventoryHistorySheet(
          entries: list,
          itemIdToName: itemIdToName,
          onClose: () => Navigator.pop(context),
        ),
      );
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.data?['error'] ?? e.message ?? 'Erreur'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _adjustStock(int itemId, int delta) async {
    if (_updatingItemIds.contains(itemId)) return;
    _updatingItemIds.add(itemId);
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
    try {
      final res = await ApiClient.dio.patch(
        '/api/admin/inventory/${widget.restaurantId}/items/$itemId',
        data: {'delta': delta},
      );
      if (!mounted) return;
      final data = res.data as Map<String, dynamic>?;
      final item = data?['item'] as Map<String, dynamic>?;
      if (item != null && inventory != null) {
        final items = List<Map<String, dynamic>>.from(inventory!['items'] as List? ?? []);
        final idx = items.indexWhere((i) => (i['itemId'] as num?)?.toInt() == itemId);
        if (idx >= 0) items[idx] = item;
        setState(() {
          inventory = Map<String, dynamic>.from(inventory!)..['items'] = items;
        });
      } else {
        _loadInventory(preserveNavigation: true);
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.data?['error'] ?? e.message ?? 'Erreur'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) _updatingItemIds.remove(itemId);
    }
  }

  Future<void> _setStockManually(int itemId, int newValue) async {
    if (_updatingItemIds.contains(itemId)) return;
    _updatingItemIds.add(itemId);
    try {
      final res = await ApiClient.dio.patch(
        '/api/admin/inventory/${widget.restaurantId}/items/$itemId',
        data: {'currentStock': newValue},
      );
      if (!mounted) return;
      final data = res.data as Map<String, dynamic>?;
      final item = data?['item'] as Map<String, dynamic>?;
      if (item != null && inventory != null) {
        final items = List<Map<String, dynamic>>.from(inventory!['items'] as List? ?? []);
        final idx = items.indexWhere((i) => (i['itemId'] as num?)?.toInt() == itemId);
        if (idx >= 0) items[idx] = item;
        setState(() {
          inventory = Map<String, dynamic>.from(inventory!)..['items'] = items;
        });
      } else {
        _loadInventory(preserveNavigation: true);
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.data?['error'] ?? e.message ?? 'Erreur'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) _updatingItemIds.remove(itemId);
    }
  }

  Future<void> _fillAllStocksTo(int value) async {
    try {
      await ApiClient.dio.post(
        '/api/admin/inventory/${widget.restaurantId}/set-all-stock',
        data: {'value': value},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tous les stocks mis à $value'), backgroundColor: Colors.green),
        );
        _loadInventory(preserveNavigation: true);
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.data?['error'] ?? e.message ?? 'Erreur'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showSetStockDialog(int itemId, int currentStock, String name) async {
    final ctrl = TextEditingController(text: '$currentStock');
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quantité en stock'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: name,
            hintText: 'Nombre de pièces',
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) {
            final v = int.tryParse(ctrl.text.trim());
            if (v != null && v >= 0) Navigator.pop(ctx, v);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text.trim());
              if (v != null && v >= 0) Navigator.pop(ctx, v);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (value != null && mounted) await _setStockManually(itemId, value);
  }

  String _getGroupLabel(String group) {
    switch (group) {
      case 'drinks': return 'Boissons';
      case 'spirits': return 'Spiritueux';
      default: return group;
    }
  }

  List<String> _typesForGroup(String group) {
    final cats = (inventory?['menuDrinkCategories'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final seen = <String>{};
    final ordered = <String>[];
    for (final cat in cats) {
      if ((cat['group'] as String?) != group) continue;
      for (final item in (cat['items'] as List?) ?? []) {
        final t = (item as Map<String, dynamic>)['type'] as String?;
        if (t != null && t.isNotEmpty && !seen.contains(t)) {
          seen.add(t);
          ordered.add(t);
        }
      }
    }
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

  List<Map<String, dynamic>> _itemsForTypeWithInventory(String group, String type) {
    final cats = (inventory?['menuDrinkCategories'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final invItems = (inventory?['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final byItemId = { for (final it in invItems) (it['itemId'] as num?)?.toInt() ?? 0: it };
    final result = <Map<String, dynamic>>[];
    for (final cat in cats) {
      if ((cat['group'] as String?) != group) continue;
      for (final menuItem in (cat['items'] as List?) ?? []) {
        final m = menuItem as Map<String, dynamic>;
        final itType = (m['type'] as String?) ?? '';
        final id = (m['id'] as num?)?.toInt();
        if (id == null) continue;
        bool match = false;
        if (type == '__VIN__') {
          match = selectedWineSubType != null ? itType == selectedWineSubType : itType.toLowerCase().startsWith('vin ');
        } else {
          match = itType == type;
        }
        if (!match) continue;
        final name = (m['name'] as String?) ?? '';
        if (searchQuery.isNotEmpty && !name.toLowerCase().contains(searchQuery.toLowerCase())) continue;
        final invItem = byItemId[id];
        result.add({'menuItem': m, 'invItem': invItem});
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (loading && inventory == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.restaurantName ?? 'Stock')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (error == 'non_initialise') {
      return Scaffold(
        appBar: AppBar(title: Text(widget.restaurantName ?? 'Stock')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text(
                  'Inventaire non initialisé',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Initialisez l\'inventaire à partir du menu (tous les groupes boissons : softs, spiritueux, vins, etc.).',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _initFromMenu,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Initialiser depuis le menu'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (error != null && error != 'non_initialise') {
      return Scaffold(
        appBar: AppBar(title: Text(widget.restaurantName ?? 'Stock')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Erreur: $error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => _loadInventory(), child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    final menuCats = (inventory?['menuDrinkCategories'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final hasNavigation = menuCats.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.restaurantName ?? 'Stock'),
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
          IconButton(icon: const Icon(Icons.history), onPressed: _showHistory, tooltip: 'Historique'),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _loadInventory(), tooltip: 'Actualiser'),
          IconButton(
            icon: const Icon(Icons.inventory),
            onPressed: () => _fillAllStocksTo(50),
            tooltip: 'Remplir tous les stocks à 50 (test)',
          ),
        ],
      ),
      body: Column(
        children: [
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
          if (hasNavigation && selectedGroup == null) ...[
            SizedBox(
              height: 54,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  _buildGroupChip('Boissons', 'drinks'),
                  _buildGroupChip('Spiritueux', 'spirits'),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
          if (selectedGroup != null && selectedType == null) ...[
            Expanded(child: _buildTypesList()),
          ],
          if (selectedType != null) ...[
            if (selectedType == '__VIN__' && selectedWineSubType == null) ...[
              Expanded(child: _buildWineSubTypes()),
            ] else ...[
              Expanded(child: _buildItemsList()),
            ],
          ],
          if (hasNavigation && selectedGroup == null && selectedType == null)
            const Expanded(child: Center(child: Text('Choisissez un groupe (Boissons ou Spiritueux)'))),
        ],
      ),
    );
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
    const wineTypes = ['Vin blanc', 'Vin rosé', 'Vin rouge', 'Vin français'];
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
    final rows = _itemsForTypeWithInventory(selectedGroup!, type);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24, top: 4),
      itemCount: rows.length,
      itemBuilder: (_, i) => _buildStockOrActivateTile(rows[i]),
    );
  }

  Widget _buildStockOrActivateTile(Map<String, dynamic> row) {
    final menuItem = row['menuItem'] as Map<String, dynamic>;
    final invItem = row['invItem'] as Map<String, dynamic>?;
    final itemId = (menuItem['id'] as num?)?.toInt() ?? 0;
    final name = menuItem['name'] as String? ?? 'Article $itemId';

    if (invItem != null) {
      final currentStock = (invItem['currentStock'] as num?)?.toInt() ?? 0;
      final threshold = (invItem['stockThreshold'] as num?)?.toInt() ?? 10;
      final isCritical = currentStock <= threshold;
      final isUpdating = _updatingItemIds.contains(itemId);
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: ListTile(
          title: Row(
            children: [
              Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
              if (isCritical)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: currentStock == 0 ? Colors.red : Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    currentStock == 0 ? 'Rupture' : 'Seuil',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: isUpdating ? null : () => _adjustStock(itemId, -1),
                  color: isCritical ? Colors.red : null,
                ),
                InkWell(
                  onTap: isUpdating ? null : () => _showSetStockDialog(itemId, currentStock, name),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 56,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    child: Text(
                      '$currentStock',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isCritical ? (currentStock == 0 ? Colors.red : Colors.orange) : null,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.grey.shade400,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: isUpdating ? null : () => _adjustStock(itemId, 1),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Opacity(
      opacity: 0.65,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: ListTile(
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: OutlinedButton.icon(
              onPressed: () async {
                try {
                  await ApiClient.dio.post('/api/admin/inventory/${widget.restaurantId}/init', data: {});
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Suivi activé pour les articles manquants'), backgroundColor: Colors.green),
                    );
                    _loadInventory(preserveNavigation: true);
                  }
                } on DioException catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.response?.data?['error'] ?? e.message ?? 'Erreur'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              icon: const Icon(Icons.add_chart, size: 18),
              label: const Text('Activer le suivi'),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sheet ergonomique et mobile-friendly pour l'historique des mouvements stock
class _InventoryHistorySheet extends StatefulWidget {
  final List<Map<String, dynamic>> entries;
  final Map<int, String> itemIdToName;
  final VoidCallback onClose;

  const _InventoryHistorySheet({
    required this.entries,
    required this.itemIdToName,
    required this.onClose,
  });

  @override
  State<_InventoryHistorySheet> createState() => _InventoryHistorySheetState();
}

class _InventoryHistorySheetState extends State<_InventoryHistorySheet> {
  String? _filterType; // null = Tous, 'sale', 'manual', 'receipt'

  List<Map<String, dynamic>> get _filteredEntries {
    if (_filterType == null) return widget.entries;
    return widget.entries.where((e) => (e['type'] as String?) == _filterType).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEntries;
    final reversed = filtered.reversed.toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                const Text(
                  'Historique des mouvements',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: widget.onClose),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _buildFilterChip('Tous', null),
                const SizedBox(width: 8),
                _buildFilterChip('Vente', 'sale'),
                const SizedBox(width: 8),
                _buildFilterChip('Ajustement', 'manual'),
                const SizedBox(width: 8),
                _buildFilterChip('Réception', 'receipt'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: reversed.isEmpty
                ? Center(
                    child: Text(
                      _filterType == null ? 'Aucun mouvement' : 'Aucun mouvement pour ce filtre',
                      style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: reversed.length,
                    itemBuilder: (_, i) => _buildHistoryTile(reversed[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? type) {
    final selected = _filterType == type;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filterType = type),
    );
  }

  Widget _buildHistoryTile(Map<String, dynamic> e) {
    final type = e['type'] as String? ?? '';
    final itemId = (e['itemId'] as num?)?.toInt() ?? 0;
    final delta = (e['delta'] as num?)?.toInt() ?? 0;
    final ts = e['timestamp'] as String? ?? '';
    final userId = e['userId'] as String? ?? '';
    final articleName = widget.itemIdToName[itemId] ?? 'Article $itemId';
    final date = ts.isNotEmpty ? DateTime.tryParse(ts) : null;
    final dateStr = date != null
        ? '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}'
        : ts;

    IconData icon;
    Color typeColor;
    String typeLabel;
    switch (type) {
      case 'sale':
        icon = Icons.shopping_cart_outlined;
        typeColor = Colors.blue;
        typeLabel = 'Vente';
        break;
      case 'receipt':
        icon = Icons.local_shipping_outlined;
        typeColor = Colors.teal;
        typeLabel = 'Réception';
        break;
      default:
        icon = Icons.tune;
        typeColor = Colors.orange;
        typeLabel = 'Ajustement';
    }

    final deltaColor = delta >= 0 ? Colors.green.shade700 : Colors.red.shade700;
    final deltaText = delta >= 0 ? '+$delta' : '$delta';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: typeColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    articleName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          typeLabel,
                          style: TextStyle(fontSize: 12, color: typeColor, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$dateStr${userId.isNotEmpty ? ' • $userId' : ''}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              deltaText,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: deltaColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
