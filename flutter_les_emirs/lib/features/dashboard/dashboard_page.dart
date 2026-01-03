import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../core/api_client.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  io.Socket? socket;

  // Onglets
  int currentTab = 0; // 0:Caisse 1:Bar 2:Cuisine 3:Service 4:Serveur

  // Données
  final List<Map<String, dynamic>> caisseOrders = [];
  final List<_StationItem> barItems = [];
  final List<_StationItem> kitchenItems = [];
  final List<_ServiceItem> serviceItems = [];
  final List<_StationItem> serverQueueItems = []; // prêts pour service
  final List<_StationItem> archiveItems = [];     // historique (servi et terminé)

  // Badges pulse
  final List<bool> pulse = [false, false, false, false, false];
  // Comptage de nouveautés par tables distinctes
  final Set<String> unseenCaisseTables = {};
  final Set<String> unseenBarTables = {};
  final Set<String> unseenKitchenTables = {};
  final Set<String> unseenServiceTables = {};
  // Nouveautés par groupe (orderId|table) pour bar/cuisine
  final Set<String> unseenBarGroups = {};
  final Set<String> unseenKitchenGroups = {};
  Timer? ticker;

  // Mapping itemId -> station via menu
  final Map<int, String> itemIdToStation = {}; // 'bar' | 'kitchen'
  final Map<int, String> itemIdToCategory = {}; // 'starter' | 'main' | 'dessert' | 'drink' | 'other'

  // Filtre / Tri
  _FilterStatus _filter = _FilterStatus.active;
  _SortMode _sort = _SortMode.urgency;

  // Mode kiosque (plein écran)
  bool _kiosk = false;

  @override
  void initState() {
    super.initState();
    _loadMenuMapping();
    _connectSocket();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    ticker?.cancel();
    socket?.dispose();
    super.dispose();
  }

  Future<void> _loadMenuMapping() async {
    try {
      final res = await ApiClient.dio
          .get('/menu/les-emirs', queryParameters: {'lng': 'fr'});
      final data = res.data as Map<String, dynamic>;
      for (final cat in (data['categories'] as List)) {
        final c = cat as Map<String, dynamic>;
        final group = (c['group'] as String?) ?? 'food';
        for (final it in (c['items'] as List)) {
          final m = it as Map<String, dynamic>;
          final id = (m['id'] as num).toInt();
          final station = (group == 'drinks' || group == 'spirits') ? 'bar' : 'kitchen';
          itemIdToStation[id] = station;
          final type = (m['type'] as String?)?.toLowerCase() ?? (m['originalType'] as String?)?.toLowerCase() ?? '';
          itemIdToCategory[id] = _mapTypeToCategory(group, type);
        }
      }
      setState(() {});
    } on DioException catch (_) {
      // fallback: anything not identified goes kitchen
    }
  }

  void _connectSocket() {
    final base = ApiClient.dio.options.baseUrl;
    final uri = base.replaceAll(RegExp(r"/+$"), '');
    final s = io.io(uri, io.OptionBuilder().setTransports(['websocket']).setExtraHeaders({'Origin': uri}).build());
    socket = s;
    s.onConnect((_) {
      setState(() {});
    });
    s.onDisconnect((_) {
      setState(() {});
    });

    // Commandes
    s.on('order:new', (payload) {
      final order = (payload as Map).cast<String, dynamic>();
      caisseOrders.insert(0, order);
      // marquer notification Caisse (par table)
      final tableForOrder = order['table']?.toString() ?? '';
      if (currentTab != 0 && tableForOrder.isNotEmpty) unseenCaisseTables.add(tableForOrder);
      // Router items
      final createdAt = DateTime.tryParse(order['createdAt'] as String? ?? '') ?? DateTime.now();
      final table = tableForOrder;
      final items = (order['items'] as List).cast<Map>();
      for (final it in items) {
        final id = (it['id'] as num).toInt();
        final qty = (it['quantity'] as num?)?.toInt() ?? 1;
        final name = it['name']?.toString() ?? 'Item $id';
        final station = itemIdToStation[id] ?? 'kitchen';
        final category = itemIdToCategory[id] ?? (station == 'bar' ? 'drink' : 'other');
        final item = _StationItem(
          station: station,
          orderId: (order['id'] as num).toInt(),
          itemId: id,
          name: name,
          quantity: qty,
          createdAt: createdAt,
          table: table,
          slaMinutes: station == 'bar' ? 5 : 20,
          category: category,
          status: _ItemStatus.newItem,
        );
        if (station == 'bar') {
          barItems.insert(0, item);
          _pulseTab(1);
          if (currentTab != 1 && table.isNotEmpty) unseenBarTables.add(table);
          final gkey = '${item.orderId}|${item.table}';
          if (currentTab != 1) unseenBarGroups.add(gkey);
        } else {
          kitchenItems.insert(0, item);
          _pulseTab(2);
          if (currentTab != 2 && table.isNotEmpty) unseenKitchenTables.add(table);
          final gkey = '${item.orderId}|${item.table}';
          if (currentTab != 2) unseenKitchenGroups.add(gkey);
        }
      }
      if (currentTab != 0) _pulseTab(0);
      setState(() {});
    });

    // Factures (pour Caisse)
    s.on('bill:new', (b) { if (currentTab != 0) _pulseTab(0); });
    s.on('bill:paid', (b) { if (currentTab != 0) _pulseTab(0); });

    // Services
    s.on('service:new', (payload) {
      final p = (payload as Map).cast<String, dynamic>();
      final createdAt = DateTime.tryParse(p['createdAt'] as String? ?? '') ?? DateTime.now();
      serviceItems.insert(0, _ServiceItem(
        id: (p['id'] as num).toInt(),
        label: p['type']?.toString() ?? 'service',
        table: p['table']?.toString() ?? '',
        createdAt: createdAt,
        slaMinutes: 5,
      ));
      final t = p['table']?.toString() ?? '';
      if (currentTab != 3) {
        _pulseTab(3);
        if (t.isNotEmpty) unseenServiceTables.add(t);
      }
      setState(() {});
    });

    s.connect();
  }

  void _pulseTab(int idx) async {
    pulse[idx] = true;
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 600));
    pulse[idx] = false;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _TabSpec('Caisse', Icons.point_of_sale),
      _TabSpec('Bar', Icons.local_bar),
      _TabSpec('Cuisine', Icons.restaurant),
      _TabSpec('Service', Icons.room_service),
      _TabSpec('Serveur', Icons.delivery_dining),
    ];
    return Scaffold(
      appBar: _kiosk ? null : AppBar(
        title: const Text('Dashboard — Les Emirs'),
        actions: [
          IconButton(onPressed: ()=> setState(()=> _kiosk = !_kiosk), icon: Icon(_kiosk ? Icons.fullscreen_exit : Icons.fullscreen)),
          Icon(socket?.connected == true ? Icons.cloud_done : Icons.cloud_off),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(children: [
        if (!_kiosk && (currentTab == 1 || currentTab == 2)) _buildToolbar(),
        SizedBox(
          height: 56,
          child: _kiosk ? const SizedBox.shrink() : ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            scrollDirection: Axis.horizontal,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemCount: tabs.length,
            itemBuilder: (_, i) {
              final isActive = i == currentTab;
              final badgeCount = (){
                switch(i){
                  case 0: return unseenCaisseTables.isNotEmpty ? unseenCaisseTables.length : 0;
                  case 1: return unseenBarTables.isNotEmpty ? unseenBarTables.length : 0;
                  case 2: return unseenKitchenTables.isNotEmpty ? unseenKitchenTables.length : 0;
                  case 3: return unseenServiceTables.isNotEmpty ? unseenServiceTables.length : 0;
                  default: return 0;
                }
              }();
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  ChoiceChip(
                    label: Text(tabs[i].label),
                    selected: isActive,
                    onSelected: (_) => setState(() {
                      currentTab = i;
                      // clear seen for this tab
                      switch(i){
                        case 0: unseenCaisseTables.clear(); break;
                        case 1: unseenBarTables.clear(); break;
                        case 2: unseenKitchenTables.clear(); break;
                        case 3: unseenServiceTables.clear(); break;
                        default: break;
                      }
                    }),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 200),
                        scale: pulse[i] ? 1.2 : 1.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10)),
                          child: Text('$badgeCount', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: switch (currentTab) {
              0 => _buildCaisse(),
              1 => _buildStationList(barItems, 'bar'),
              2 => _buildStationList(kitchenItems, 'kitchen'),
              3 => _buildServices(),
              _ => _buildServeur(),
            },
          ),
        ),
      ]),
    );
  }

  // Toolbar filtre/tri pour Bar & Cuisine
  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(children: [
        // Filtre
        DropdownButton<_FilterStatus>(
          value: _filter,
          items: const [
            DropdownMenuItem(value: _FilterStatus.active, child: Text('En cours')),
            DropdownMenuItem(value: _FilterStatus.done, child: Text('Terminés')),
            DropdownMenuItem(value: _FilterStatus.all, child: Text('Tous')),
          ],
          onChanged: (v) => setState(() => _filter = v ?? _FilterStatus.active),
        ),
        const SizedBox(width: 12),
        // Tri
        DropdownButton<_SortMode>(
          value: _sort,
          items: const [
            DropdownMenuItem(value: _SortMode.urgency, child: Text('Urgence')),
            DropdownMenuItem(value: _SortMode.table, child: Text('Table')),
            DropdownMenuItem(value: _SortMode.age, child: Text('Ancienneté')),
          ],
          onChanged: (v) => setState(() => _sort = v ?? _SortMode.urgency),
        ),
      ]),
    );
  }

  Widget _buildCaisse() {
    return ListView.separated(
      itemCount: caisseOrders.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final o = caisseOrders[i];
        final id = (o['id'] as num?)?.toInt() ?? 0;
        final table = o['table']?.toString() ?? '';
        final total = (o['total'] as num?)?.toDouble() ?? 0;
        final createdAt = DateTime.tryParse(o['createdAt'] as String? ?? '') ?? DateTime.now();
        return ListTile(
          title: Text('Commande #$id — Table $table'),
          subtitle: Text(_fmtTime(createdAt)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('${total.toStringAsFixed(2)} TND', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Détails',
              icon: const Icon(Icons.receipt_long),
              onPressed: () => _showOrderDetails(o),
            ),
          ]),
        );
      },
    );
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    final items = (order['items'] as List).cast<Map<String, dynamic>>();
    showDialog(context: context, builder: (_) {
      return AlertDialog(
        title: Text('Commande #${order['id']} — Table ${order['table']}'),
        content: SizedBox(
          width: 420,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final it = items[i];
              final name = it['name']?.toString() ?? '';
              final qty = (it['quantity'] as num?)?.toInt() ?? 0;
              final price = (it['price'] as num?)?.toDouble() ?? 0;
              return ListTile(
                title: Text(name),
                trailing: Text('× $qty  •  ${(price * qty).toStringAsFixed(2)} TND'),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(context), child: const Text('Fermer')),
        ],
      );
    });
  }

  Widget _buildStationList(List<_StationItem> items, String station) {
    // Propager les paramètres de filtre/tri à l’espace global utilisé par les helpers
    _filterGlobal = _filter;
    _sortGlobal = _sort;
    _currentTabGlobal = currentTab;
    // Choisir la source selon le filtre (active=liste de travail, done/all=archives)
    final source = (_filter == _FilterStatus.active)
        ? items
        : archiveItems.where((it) => it.station == station).toList();
    // Filtrer par statut
    final visible = _applyFilters(source);
    // Grouper par (orderId, table)
    final groups = _groupByOrderAndTable(visible, station);
    // Trier par urgence (ratio le plus élevé en dernier, donc on inverse pour le plus urgent en haut)
    _sortGroups(groups);
    return ListView.separated(
      itemCount: groups.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final g = groups[i];
        // En cuisine, priorité visuelle aux catégories: on prend la couleur selon le pire item
        final color = _lerpUrgencyColor(g.worstElapsedRatio.clamp(0.0, 1.2));
        final remainingMin = g.remainingMinutes;
        final gkey = '${g.orderId}|${g.table}';
        final isNew = station == 'bar' ? unseenBarGroups.contains(gkey) : unseenKitchenGroups.contains(gkey);
        return Container(
          color: color.withOpacity(0.08),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 12.0),
            title: Row(children: [
              Expanded(child: Text('Table ${g.table} • Cmd #${g.orderId} • ${g.items.length} article(s)', style: const TextStyle(fontWeight: FontWeight.w600))),
              if (isNew)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10)),
                  child: const Text('Nouveau', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ]),
            subtitle: Text('${_fmtTime(g.createdAt)} • SLA ${g.slaMinutes} min'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Led(color: color),
                const SizedBox(height: 6),
                Text('$remainingMin min'),
              ],
            ),
            children: [
              const Divider(height: 1),
              // actions groupe
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Row(children: [
                  if (station == 'kitchen') ...[
                    ElevatedButton.icon(onPressed: () => _markGroupStatus(g, _ItemStatus.inProgress), icon: const Icon(Icons.play_arrow), label: const Text('Débuter préparation')),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(onPressed: () => _markGroupReadyForService(g), icon: const Icon(Icons.check), label: const Text('Prêt pour service')),
                  ] else ...[
                    ElevatedButton.icon(onPressed: () => _markGroupStatus(g, _ItemStatus.inProgress), icon: const Icon(Icons.play_arrow), label: const Text('Pris')),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(onPressed: () => _markGroupReadyForService(g), icon: const Icon(Icons.check), label: const Text('Terminé')),
                  ],
                  const Spacer(),
                ]),
              ),
                      const Divider(height: 1),
                      // Affichage par catégories (séparateurs)
                      ..._buildItemsByCategory(g.items, station),
                      const SizedBox(height: 6),
            ],
            onExpansionChanged: (open){
              if (open) {
                if (station == 'bar') unseenBarGroups.remove(gkey);
                else unseenKitchenGroups.remove(gkey);
                setState(() {});
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildServices() {
    return ListView.separated(
      itemCount: serviceItems.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final s = serviceItems[i];
        final ratio = s.elapsedRatio().clamp(0.0, 1.2);
        final color = _lerpUrgencyColor(ratio);
        final remaining = s.remainingMinutes().clamp(0, s.slaMinutes);
        return Container(
          color: color.withOpacity(0.12),
          child: ListTile(
            title: Text('${s.label} — Table ${s.table}'),
            subtitle: Text(_fmtTime(s.createdAt)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Led(color: color),
                const SizedBox(height: 6),
                Text('$remaining min'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildServeur() {
    // Grouper la file serveur par table/commande
    final groups = _groupByOrderAndTable(serverQueueItems, 'server');
    groups.sort((a, b) => a.table.compareTo(b.table));
    return ListView.separated(
      itemCount: groups.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final g = groups[i];
        return ExpansionTile(
          title: Text('Table ${g.table} • Cmd #${g.orderId} • ${g.items.length} article(s)', style: const TextStyle(fontWeight: FontWeight.w600)),
          children: [
            ...g.items.map((it) => ListTile(
              title: Text(it.name),
              trailing: Text('× ${it.quantity}'),
            )),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
              child: Row(children: [
                ElevatedButton.icon(onPressed: () => _markGroupServed(g), icon: const Icon(Icons.delivery_dining), label: const Text('Marquer comme Servi')),
                const Spacer(),
              ]),
            )
          ],
        );
      },
    );
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Color _lerpUrgencyColor(double t) {
    // 0 -> vert, 0.5 -> orange, 1 -> rouge
    final mid = Color.lerp(Colors.green, Colors.orange, t.clamp(0.0, 0.5) * 2)!;
    final end = Color.lerp(Colors.orange, Colors.red, (t - 0.5).clamp(0.0, 0.5) * 2)!;
    return t <= 0.5 ? mid : end;
  }

  void _markItemStatus(_StationItem it, _ItemStatus s) {
    setState(() {
      it.status = s;
    });
  }

  void _markGroupStatus(_StationGroup g, _ItemStatus s) {
    setState(() {
      for (final it in g.items) {
        it.status = s;
      }
    });
  }

  void _markGroupReadyForService(_StationGroup g) {
    setState(() {
      final isBar = g.items.first.station == 'bar';
      final source = isBar ? barItems : kitchenItems;
      final moved = <_StationItem>[];
      source.removeWhere((it) {
        final match = it.orderId == g.orderId && it.table == g.table;
        if (match) {
          it.status = _ItemStatus.readyForService;
          moved.add(it);
        }
        return match;
      });
      serverQueueItems.addAll(moved);
    });
  }

  void _markGroupServed(_StationGroup g) {
    setState(() {
      final moved = <_StationItem>[];
      serverQueueItems.removeWhere((it) {
        final match = it.orderId == g.orderId && it.table == g.table;
        if (match) {
          it.status = _ItemStatus.served;
          moved.add(it);
        }
        return match;
      });
      archiveItems.addAll(moved);
    });
  }

  List<Widget> _buildItemsByCategory(List<_StationItem> items, String station) {
    // Tri local par catégorie puis par ancienneté (visuel clair)
    int rank(String c) {
      switch (c) {
        case 'starter': return 0;
        case 'main': return 1;
        case 'dessert': return 2;
        case 'drink': return 3;
        default: return 4;
      }
    }
    final sorted = List<_StationItem>.from(items)
      ..sort((a, b) {
        final r = rank(a.category).compareTo(rank(b.category));
        if (r != 0) return r;
        return a.createdAt.compareTo(b.createdAt);
      });
    final out = <Widget>[];
    String? lastCat;
    for (final it in sorted) {
      if (it.category != lastCat) {
        lastCat = it.category;
        out.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Center(child: Text(_categoryTitle(it.category), style: const TextStyle(fontWeight: FontWeight.w700))),
        ));
      }
      out.add(ListTile(
        dense: false,
        title: Text('${it.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          _statusIcon(it.status),
          const SizedBox(width: 8),
          Text('× ${it.quantity}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          IconButton(onPressed: () => _markItemStatus(it, _ItemStatus.inProgress), icon: const Icon(Icons.play_circle_outline, size: 28)),
          IconButton(onPressed: () => _markItemStatus(it, _ItemStatus.done), icon: const Icon(Icons.check_circle_outline, size: 28)),
        ]),
      ));
    }
    return out;
  }
}

class _TabSpec {
  final String label;
  final IconData icon;
  _TabSpec(this.label, this.icon);
}

class _Led extends StatelessWidget {
  final Color color;
  const _Led({required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
    );
  }
}

class _StationItem {
  final String station; // 'bar' | 'kitchen'
  final int orderId;
  final int itemId;
  final String name;
  final int quantity;
  final DateTime createdAt;
  final String table;
  final int slaMinutes; // 5 or 20
  final String category; // starter | main | dessert | drink | other
  _ItemStatus status;
  _StationItem({
    required this.station,
    required this.orderId,
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.createdAt,
    required this.table,
    required this.slaMinutes,
    required this.category,
    required this.status,
  });
  double elapsedRatio() {
    final elapsed = DateTime.now().difference(createdAt).inSeconds.toDouble();
    final sla = slaMinutes * 60.0;
    return (elapsed / sla).clamp(0, 2);
  }
  int remainingMinutes() {
    final remain = slaMinutes - DateTime.now().difference(createdAt).inMinutes;
    return remain;
  }
  double remainingRatio(String station) => 1.0 - elapsedRatio();
}

class _StationGroup {
  final int orderId;
  final String table;
  final int slaMinutes; // station-level SLA
  final DateTime createdAt; // de la commande
  final List<_StationItem> items;
  _StationGroup({required this.orderId, required this.table, required this.slaMinutes, required this.createdAt, required this.items});
  double get worstElapsedRatio => items.fold<double>(0.0, (m, e) => e.elapsedRatio() > m ? e.elapsedRatio() : m);
  int get remainingMinutes => items.map((e) => e.remainingMinutes()).reduce((a, b) => a < b ? a : b);
}

List<_StationGroup> _groupByOrderAndTable(List<_StationItem> items, String station) {
  final map = <String, List<_StationItem>>{}; // key = orderId|table
  for (final it in items) {
    final key = '${it.orderId}|${it.table}';
    map.putIfAbsent(key, () => []).add(it);
  }
  final groups = <_StationGroup>[];
  for (final entry in map.entries) {
    final list = entry.value;
    if (list.isEmpty) continue;
    final first = list.first;
    groups.add(_StationGroup(
      orderId: first.orderId,
      table: first.table,
      slaMinutes: station == 'bar' ? 5 : 20,
      createdAt: first.createdAt,
      items: list,
    ));
  }
  return groups;
}

enum _ItemStatus { newItem, inProgress, readyForService, served, done }
enum _FilterStatus { active, done, all }
enum _SortMode { urgency, table, age }

List<_StationItem> _applyFilters(List<_StationItem> items) {
  return items.where((it) {
    switch (_filterGlobal) {
      case _FilterStatus.active:
        return it.status == _ItemStatus.newItem || it.status == _ItemStatus.inProgress;
      case _FilterStatus.done:
        return it.status == _ItemStatus.readyForService || it.status == _ItemStatus.served || it.status == _ItemStatus.done;
      case _FilterStatus.all:
        return true;
    }
  }).toList();
}

void _sortGroups(List<_StationGroup> groups) {
  // Si on est en Cuisine, prioriser par catégorie (entrée -> plat -> dessert) avant d’appliquer le tri choisi
  int categoryRank(_StationGroup g) {
    // Catégorie dominante = catégorie de l’item le plus ancien
    _StationItem? oldest;
    for (final it in g.items) {
      if (oldest == null || it.createdAt.isBefore(oldest.createdAt)) oldest = it;
    }
    final cat = oldest?.category ?? 'other';
    switch (cat) {
      case 'starter': return 0;
      case 'main': return 1;
      case 'dessert': return 2;
      default: return 3;
    }
  }

  if (_currentTabGlobal == 2) {
    groups.sort((a, b) {
      final cr = categoryRank(a).compareTo(categoryRank(b));
      if (cr != 0) return cr;
      // Sinon, appliquer le tri sélectionné
      switch (_sortGlobal) {
        case _SortMode.urgency:
          return b.worstElapsedRatio.compareTo(a.worstElapsedRatio);
        case _SortMode.table:
          return a.table.compareTo(b.table);
        case _SortMode.age:
          return a.createdAt.compareTo(b.createdAt);
      }
    });
    return;
  }

  switch (_sortGlobal) {
    case _SortMode.urgency:
      groups.sort((a, b) => b.worstElapsedRatio.compareTo(a.worstElapsedRatio));
      break;
    case _SortMode.table:
      groups.sort((a, b) => a.table.compareTo(b.table));
      break;
    case _SortMode.age:
      groups.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      break;
  }
}

// Ces deux variables seront assignées depuis l'état (_filter/_sort)
late _FilterStatus _filterGlobal;
late _SortMode _sortGlobal;
late int _currentTabGlobal;

String _statusLabel(_ItemStatus s) {
  switch (s) {
    case _ItemStatus.newItem:
      return 'Nouveau';
    case _ItemStatus.inProgress:
      return 'En cours';
    case _ItemStatus.readyForService:
      return 'Prêt';
    case _ItemStatus.served:
      return 'Servi';
    case _ItemStatus.done:
      return 'Terminé';
  }
}

String _categoryTitle(String cat) {
  switch (cat) {
    case 'starter': return '*** ENTRÉES ***';
    case 'main': return '*** PLATS ***';
    case 'dessert': return '*** DESSERTS ***';
    case 'drink': return '*** BOISSONS ***';
    default: return '*** AUTRES ***';
  }
}

Widget _statusIcon(_ItemStatus s) {
  switch (s) {
    case _ItemStatus.newItem:
      return const Icon(Icons.radio_button_on, color: Colors.orange, size: 18);
    case _ItemStatus.inProgress:
      return const Icon(Icons.radio_button_on, color: Colors.amber, size: 18);
    case _ItemStatus.readyForService:
      return const Icon(Icons.check_circle, color: Colors.blue, size: 18);
    case _ItemStatus.served:
      return const Icon(Icons.check_circle, color: Colors.green, size: 18);
    case _ItemStatus.done:
      return const Icon(Icons.check_circle, color: Colors.green, size: 18);
  }
}

String _mapTypeToCategory(String group, String typeLower) {
  if (group == 'drinks' || group == 'spirits') return 'drink';
  if (typeLower.contains('entrée')) return 'starter';
  if (typeLower.contains('plat') || typeLower.contains('viande') || typeLower.contains('volaille') || typeLower.contains('poisson') || typeLower.contains('pâtes')) return 'main';
  if (typeLower.contains('dessert')) return 'dessert';
  return 'other';
}

class _ServiceItem {
  final int id;
  final String label;
  final String table;
  final DateTime createdAt;
  final int slaMinutes; // 5
  _ServiceItem({required this.id, required this.label, required this.table, required this.createdAt, required this.slaMinutes});
  double elapsedRatio() {
    final elapsed = DateTime.now().difference(createdAt).inSeconds.toDouble();
    final sla = slaMinutes * 60.0;
    return (elapsed / sla).clamp(0, 2);
  }
  int remainingMinutes() {
    final remain = slaMinutes - DateTime.now().difference(createdAt).inMinutes;
    return remain;
  }
}


