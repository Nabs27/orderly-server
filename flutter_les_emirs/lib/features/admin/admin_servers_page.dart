import 'package:flutter/material.dart';
import 'services/servers_service.dart';

class AdminServersPage extends StatefulWidget {
  const AdminServersPage({super.key});

  @override
  State<AdminServersPage> createState() => _AdminServersPageState();
}

class _AdminServersPageState extends State<AdminServersPage> {
  final Map<String, String> permissionLabels = const {
    'canTransferNote': 'Transférer vers une autre note',
    'canTransferTable': 'Transférer vers une autre table',
    'canTransferServer': 'Changer de serveur',
    'canCancelItems': 'Annuler des articles',
    'canEditCovers': 'Modifier les couverts',
    'canOpenDebt': 'Accéder aux dettes clients',
    'canOpenPayment': 'Ouvrir l’écran de paiement',
  };

  List<ServerProfile> _profiles = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profiles = await ServersService.loadProfiles();
      if (mounted) {
        setState(() {
          _profiles = profiles;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _showSnack(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color ?? Colors.blueGrey),
    );
  }

  Future<void> _showEditDialog({ServerProfile? profile}) async {
    final nameCtrl = TextEditingController(text: profile?.name ?? '');
    final pinCtrl = TextEditingController(text: profile?.pin ?? '');
    String role = profile?.role ?? 'Serveur';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(profile == null ? 'Nouveau serveur' : 'Modifier ${profile.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nom'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinCtrl,
              decoration: const InputDecoration(labelText: 'PIN'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: role,
              decoration: const InputDecoration(labelText: 'Rôle'),
              items: const [
                DropdownMenuItem(value: 'Serveur', child: Text('Serveur')),
                DropdownMenuItem(value: 'Caissier', child: Text('Caissier')),
                DropdownMenuItem(value: 'Manager', child: Text('Manager')),
              ],
              onChanged: (value) => role = value ?? 'Serveur',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(profile == null ? 'Créer' : 'Mettre à jour'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final name = nameCtrl.text.trim();
    final pin = pinCtrl.text.trim();

    if (name.isEmpty || pin.isEmpty) {
      _showSnack('Nom et PIN sont requis', color: Colors.red);
      return;
    }

    try {
      if (profile == null) {
        await ServersService.createProfile(name: name, pin: pin, role: role);
      } else {
        await ServersService.updateProfile(
          profile.copyWith(name: name.toUpperCase(), pin: pin, role: role),
        );
      }
      await _loadProfiles();
      _showSnack('Profil sauvegardé', color: Colors.green.shade600);
    } catch (e) {
      _showSnack('Erreur: $e', color: Colors.red);
    }
  }

  Future<void> _togglePermission(ServerProfile profile, String key, bool value) async {
    try {
      final updated = profile.permissions.map((k, v) => MapEntry(k, k == key ? value : v));
      await ServersService.updateProfile(profile.copyWith(permissions: updated));
      await _loadProfiles();
    } catch (e) {
      _showSnack('Erreur mise à jour permission: $e', color: Colors.red);
    }
  }

  Future<void> _deleteProfile(ServerProfile profile) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le serveur ?'),
        content: Text('Voulez-vous supprimer ${profile.name} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ServersService.deleteProfile(profile.id);
      await _loadProfiles();
      _showSnack('Profil supprimé', color: Colors.green.shade600);
    } catch (e) {
      _showSnack('Erreur suppression: $e', color: Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profils serveurs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProfiles,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditDialog(),
        icon: const Icon(Icons.person_add),
        label: const Text('Nouveau profil'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Erreur: $_error'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadProfiles,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (_profiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Aucun profil serveur.'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _showEditDialog(),
              child: const Text('Créer un profil'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) {
        final profile = _profiles[index];
        return Card(
          elevation: 2,
          child: ExpansionTile(
            title: Text(profile.name),
            subtitle: Text(profile.role),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('PIN: ${profile.pin}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        tooltip: 'Modifier',
                        onPressed: () => _showEditDialog(profile: profile),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Supprimer',
                        onPressed: () => _deleteProfile(profile),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(),
              ...permissionLabels.entries.map(
                (entry) => SwitchListTile(
                  title: Text(entry.value),
                  value: profile.permissions[entry.key] ?? true,
                  onChanged: (value) => _togglePermission(profile, entry.key, value),
                ),
              ),
            ],
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: _profiles.length,
    );
  }
}

