import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:file_picker/file_picker.dart';
import '../../core/api_client.dart';
import 'admin_credit_page.dart';
import 'admin_menu_editor_page.dart';
import 'admin_servers_page.dart';
import 'report_x_page.dart';
import 'pages/diagnostic_page.dart';
import 'widgets/admin_dashboard_kpi_section.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});
  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  List<Map<String, dynamic>> restaurants = [];
  bool loading = true;
  String? error;
  io.Socket? socket;
  final GlobalKey<AdminDashboardKpiSectionState> _kpiKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
    _connectSocket();
  }

  @override
  void dispose() {
    socket?.dispose();
    super.dispose();
  }

  void _connectSocket() {
    final base = ApiClient.dio.options.baseUrl;
    final uri = base.replaceAll(RegExp(r"/+\$"), '');
    final s = io.io(uri, io.OptionBuilder().setTransports(['websocket']).setExtraHeaders({'Origin': uri}).build());
    socket = s;
    s.on('menu:updated', (_) => _loadRestaurants());
    s.connect();
  }

  Future<void> _loadRestaurants() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await ApiClient.dio.get('/api/admin/restaurants');
      final list = (res.data as List).cast<Map<String, dynamic>>();
      setState(() {
        restaurants = list;
        loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        error = e.response?.data['error'] ?? e.message;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> _createRestaurant() async {
    final idCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final currencyCtrl = TextEditingController(text: 'TND');
    
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nouveau Restaurant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: idCtrl, decoration: const InputDecoration(labelText: 'ID (ex: les-emirs)')),
            const SizedBox(height: 12),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom du restaurant')),
            const SizedBox(height: 12),
            TextField(controller: currencyCtrl, decoration: const InputDecoration(labelText: 'Devise (ex: TND, EUR)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final id = idCtrl.text.trim();
              final name = nameCtrl.text.trim();
              final currency = currencyCtrl.text.trim();
              if (id.isEmpty || name.isEmpty) return;
              try {
                await ApiClient.dio.post('/api/admin/restaurants', data: {'id': id, 'name': name, 'currency': currency});
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                }
              }
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    if (ok == true) _loadRestaurants();
  }

  Future<void> _uploadPDFMenu() async {
    // Demander les infos restaurant
    final idCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final currencyCtrl = TextEditingController(text: 'TND');
    
    final proceed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Importer / mettre à jour un menu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Sélectionnez un PDF ou des photos du menu. L\'IA crée ou met à jour automatiquement votre catalogue.'),
            const SizedBox(height: 16),
            TextField(controller: idCtrl, decoration: const InputDecoration(labelText: 'ID restaurant (ex: pizzeria-roma)')),
            const SizedBox(height: 12),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom du restaurant')),
            const SizedBox(height: 12),
            TextField(controller: currencyCtrl, decoration: const InputDecoration(labelText: 'Devise (ex: TND, EUR)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sélectionner PDF')),
        ],
      ),
    );
    
    if (proceed != true) return;
    
    final id = idCtrl.text.trim();
    final name = nameCtrl.text.trim();
    final currency = currencyCtrl.text.trim();
    if (id.isEmpty || name.isEmpty) return;
    
    // Sélectionner fichier
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    
    // Upload et parsing
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(file.bytes!, filename: file.name),
        'restaurantId': id,
        'restaurantName': name,
        'currency': currency,
      });
      final res = await ApiClient.dio.post('/api/admin/parse-menu', data: formData);
      final parsedMenu = (res.data as Map<String, dynamic>)['menu'] as Map<String, dynamic>;
      
      if (!mounted) return;
      Navigator.pop(context); // fermer loading
      
      // Sauvegarder le menu parsé
      await ApiClient.dio.post('/api/admin/restaurants', data: {'id': id, 'name': name, 'currency': currency});
      await ApiClient.dio.patch('/api/admin/menu/$id', data: {'menu': parsedMenu});
      
      _loadRestaurants();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Menu créé avec succès !')));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // fermer loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1200;
        final isTablet = constraints.maxWidth >= 800 && constraints.maxWidth < 1200;
        final shortcuts = _buildShortcuts();

    return Scaffold(
          backgroundColor: const Color(0xFFF5F6FB),
          drawer: isDesktop ? null : Drawer(child: _buildDrawerContent(shortcuts)),
      appBar: AppBar(
        title: const Text('Dashboard Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadRestaurants();
              _kpiKey.currentState?.refresh();
            },
          ),
        ],
      ),
          body: _buildDashboardBody(isDesktop, isTablet, shortcuts),
        );
      },
    );
  }

  Widget _buildDashboardBody(bool isDesktop, bool isTablet, List<_AdminShortcut> shortcuts) {
    Widget content;

    if (loading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (error != null) {
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade400, size: 48),
            const SizedBox(height: 12),
            Text('Erreur: $error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(onPressed: _loadRestaurants, icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
          ],
        ),
      );
    } else {
      content = CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: AdminDashboardKpiSection(key: _kpiKey)),
          SliverToBoxAdapter(child: _buildSectionTitle('Restaurants actifs')),
          if (restaurants.isEmpty)
            SliverToBoxAdapter(child: _buildEmptyState())
          else
            _buildRestaurantsGrid(isDesktop, isTablet),
          const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isDesktop) SizedBox(width: 280, child: _buildSidePanel(shortcuts)),
        Expanded(child: content),
      ],
    );
  }


  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const Spacer(),
          TextButton.icon(onPressed: _loadRestaurants, icon: const Icon(Icons.refresh, size: 18), label: const Text('Rafraîchir')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
                  children: [
            Icon(Icons.widgets_outlined, size: 58, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('Aucun restaurant configuré', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Importez un menu PDF ou créez un restaurant depuis les actions rapides.'),
            const SizedBox(height: 20),
            ElevatedButton.icon(onPressed: _createRestaurant, icon: const Icon(Icons.add), label: const Text('Nouveau restaurant')),
          ],
        ),
      ),
    );
  }

  SliverPadding _buildRestaurantsGrid(bool isDesktop, bool isTablet) {
    final crossAxisCount = isDesktop
        ? 2
        : isTablet
            ? 2
            : 1;
    final aspect = isDesktop
        ? 2.6
        : isTablet
            ? 2.1
            : 1.05;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: aspect,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final r = restaurants[index];
            return _RestaurantCard(
              data: r,
              onEdit: () => _openMenuEditor(r['id']),
              onHidden: () => _openMenuEditor(r['id'], quick: 'hidden'),
              onUnavailable: () => _openMenuEditor(r['id'], quick: 'unavailable'),
            );
          },
          childCount: restaurants.length,
        ),
      ),
    );
  }

  Widget _buildSidePanel(List<_AdminShortcut> shortcuts) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Actions rapides', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: shortcuts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _ShortcutCard(shortcut: shortcuts[index]),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: const [
                Icon(Icons.wifi_tethering, color: Colors.teal),
                SizedBox(width: 8),
                Expanded(child: Text('Socket temps réel actif', style: TextStyle(fontWeight: FontWeight.w600))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerContent(List<_AdminShortcut> shortcuts) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Navigation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: shortcuts.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (context, index) {
                final shortcut = shortcuts[index];
                return ListTile(
                  leading: Icon(shortcut.icon, color: Colors.teal),
                  title: Text(shortcut.title),
                  subtitle: Text(shortcut.subtitle),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await shortcut.action();
                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }


  List<_AdminShortcut> _buildShortcuts() {
    return [
      _AdminShortcut(
        icon: Icons.restaurant_menu,
        title: 'Menu & catalogues',
        subtitle: 'Choisir un établissement à éditer',
        action: _openMenuSelector,
      ),
      _AdminShortcut(
        icon: Icons.upload_file,
        title: 'Importer menu IA',
        subtitle: 'PDF ou photos pour créer OU mettre à jour',
        action: _uploadPDFMenu,
      ),
      _AdminShortcut(
        icon: Icons.inventory_2_outlined,
        title: 'Stock & inventaire',
        subtitle: 'Module en préparation',
        action: _openStockPreview,
      ),
      _AdminShortcut(
        icon: Icons.admin_panel_settings,
        title: 'Profils serveurs',
        subtitle: 'Rôles et autorisations',
        action: _openServersPage,
      ),
      _AdminShortcut(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Crédit client',
        subtitle: 'Dettes et transactions',
        action: _openCreditPage,
      ),
      _AdminShortcut(
        icon: Icons.receipt_long,
        title: 'Rapport X',
        subtitle: 'Suivi réglementaire',
        action: _openReportXPage,
      ),
      _AdminShortcut(
        icon: Icons.bug_report,
        title: 'Diagnostic données',
        subtitle: 'Comparer les sources de données',
        action: _openDiagnosticPage,
      ),
    ];
  }

  Future<void> _openMenuSelector() async {
    if (restaurants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun restaurant disponible. Importez un menu pour commencer.')),
      );
      return;
    }

    // Si un seul menu, l'ouvrir directement
    if (restaurants.length == 1) {
      await _openMenuEditor(restaurants.first['id']);
      return;
    }

    // Sinon, afficher le dialog de choix au centre
    await showDialog(
      context: context,
      builder: (dialogContext) {
        final screenWidth = MediaQuery.of(context).size.width;
        final dialogWidth = screenWidth > 500 ? 500.0 : screenWidth * 0.9;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            width: dialogWidth,
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Choisir un menu à éditer',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: restaurants.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final r = restaurants[index];
                      return ListTile(
                        leading: const Icon(Icons.restaurant, color: Colors.teal),
                        title: Text(
                          r['name'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text('${r['id']} • ${r['categoriesCount']} cat. • ${r['itemsCount']} articles'),
                        onTap: () async {
                          Navigator.of(dialogContext).pop();
                          await _openMenuEditor(r['id']);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openStockPreview() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Stock & inventaire'),
        content: const Text('Module en préparation : suivi des matières, alertes de seuil et inventaires physiques seront ajoutés bientôt.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _openMenuEditor(String restaurantId, {String? quick}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AdminMenuEditorPage(restaurantId: restaurantId, openQuick: quick)),
    );
    if (mounted) {
      _loadRestaurants();
    }
  }

  Future<void> _openServersPage() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminServersPage()));
  }

  Future<void> _openCreditPage() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminCreditPage()));
  }

  Future<void> _openReportXPage() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReportXPage()));
  }

  Future<void> _openDiagnosticPage() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DiagnosticPage()));
  }
}

class _ShortcutCard extends StatelessWidget {
  final _AdminShortcut shortcut;

  const _ShortcutCard({required this.shortcut});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: shortcut.action,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: Colors.teal.withOpacity(0.1), foregroundColor: Colors.teal, child: Icon(shortcut.icon)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shortcut.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(shortcut.subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _AdminShortcut {
  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function() action;

  const _AdminShortcut({required this.icon, required this.title, required this.subtitle, required this.action});
}

class _RestaurantCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onHidden;
  final VoidCallback onUnavailable;

  const _RestaurantCard({required this.data, required this.onEdit, required this.onHidden, required this.onUnavailable});

  @override
  Widget build(BuildContext context) {
    final hidden = data['hiddenCount'] ?? 0;
    final unavailable = data['unavailableCount'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 18, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 26, backgroundColor: Colors.teal.withOpacity(0.1), child: const Icon(Icons.restaurant, color: Colors.teal)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text(
                      '${data['id']} • ${data['categoriesCount']} catégories • ${data['itemsCount']} articles',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              IconButton(tooltip: 'Ouvrir l\'éditeur', onPressed: onEdit, icon: const Icon(Icons.open_in_new)),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatChip(icon: Icons.visibility_off, label: 'Masqués', value: hidden.toString(), color: Colors.blueGrey),
              _StatChip(icon: Icons.report_problem, label: 'Indispo', value: unavailable.toString(), color: Colors.orange),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(child: OutlinedButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit), label: const Text('Éditer'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: onHidden, icon: const Icon(Icons.visibility_off), label: const Text('Masqués'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: onUnavailable, icon: const Icon(Icons.warning), label: const Text('Indispo'))),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text('$label :', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}
