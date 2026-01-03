import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/home/PosHomePage_refactor.dart';

class PosLoginPage extends StatefulWidget {
  const PosLoginPage({super.key});
  @override
  State<PosLoginPage> createState() => _PosLoginPageState();
}

class _PosLoginPageState extends State<PosLoginPage> {
  final _cardController = TextEditingController();
  final _pinController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _usePinMode = false;
  final _cardFocus = FocusNode();

  // Base de données serveurs/caissiers (à terme: API ou fichier config)
  final Map<String, Map<String, String>> _users = {
    '001': {'name': 'MOHAMED', 'role': 'Caissier', 'pin': '1234'},
    '002': {'name': 'ALI', 'role': 'Serveur', 'pin': '2345'},
    '003': {'name': 'FATIMA', 'role': 'Serveur', 'pin': '3456'},
    '004': {'name': 'ADMIN', 'role': 'Manager', 'pin': '0000'},
  };

  @override
  void initState() {
    super.initState();
    // Auto-focus sur le champ carte pour scan immédiat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_usePinMode) _cardFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _cardController.dispose();
    _pinController.dispose();
    _cardFocus.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    await Future.delayed(const Duration(milliseconds: 300)); // Simule validation

    final cardId = _cardController.text.trim();
    final pin = _pinController.text.trim();

    if (_usePinMode) {
      // Mode PIN: chercher par code
      final user = _users.entries.firstWhere(
        (e) => e.value['pin'] == pin,
        orElse: () => MapEntry('', {}),
      );
      if (user.value.isEmpty) {
        setState(() {
          _error = 'Code PIN invalide';
          _loading = false;
        });
        return;
      }
      await _loginSuccess(user.key, user.value['name']!, user.value['role']!);
    } else {
      // Mode Carte: chercher par ID carte
      if (!_users.containsKey(cardId)) {
        setState(() {
          _error = 'Carte non reconnue';
          _loading = false;
        });
        return;
      }
      final user = _users[cardId]!;
      await _loginSuccess(cardId, user['name']!, user['role']!);
    }
  }

  Future<void> _loginSuccess(String userId, String name, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pos_user_id', userId);
    await prefs.setString('pos_user_name', name);
    await prefs.setString('pos_user_role', role);
    await prefs.setString('pos_session_start', DateTime.now().toIso8601String());

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PosHomePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C3E50),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(32),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo / Titre
                  const Icon(Icons.point_of_sale, size: 80, color: Color(0xFF3498DB)),
                  const SizedBox(height: 16),
                  const Text(
                    'MACAISE',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                  ),
                  const Text(
                    'Point de Vente — Les Emirs',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 40),

                  // Mode toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.credit_card, color: Colors.grey),
                      const SizedBox(width: 8),
                      Switch(
                        value: _usePinMode,
                        onChanged: (v) {
                          setState(() {
                            _usePinMode = v;
                            _error = null;
                            _cardController.clear();
                            _pinController.clear();
                          });
                          if (!v) {
                            Future.delayed(const Duration(milliseconds: 100), () {
                              _cardFocus.requestFocus();
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.pin, color: Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Champ de saisie
                  if (_usePinMode) ...[
                    TextField(
                      controller: _pinController,
                      autofocus: true,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, letterSpacing: 8),
                      decoration: const InputDecoration(
                        labelText: 'Code PIN',
                        hintText: '••••',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _authenticate(),
                    ),
                  ] else ...[
                    TextField(
                      controller: _cardController,
                      focusNode: _cardFocus,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20),
                      decoration: const InputDecoration(
                        labelText: 'Scannez votre carte',
                        hintText: 'Passez votre badge...',
                        prefixIcon: Icon(Icons.credit_card),
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _authenticate(),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Erreur
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Bouton connexion
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _authenticate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3498DB),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('SE CONNECTER', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Aide
                  Text(
                    _usePinMode ? 'Entrez votre code PIN à 4 chiffres' : 'Utilisez le scanner de carte ou cliquez sur le bouton PIN',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

