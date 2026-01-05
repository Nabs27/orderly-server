import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/api_client.dart';
import '../../core/auth_service.dart';
import 'admin_dashboard_page.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});
  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    final password = _passwordCtrl.text.trim();
    if (password.isEmpty) {
      setState(() => _error = 'Mot de passe requis');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Debug: Afficher l'URL de base
      
      final res = await ApiClient.dio.post('/api/admin/login', data: {'password': password});
      final data = res.data as Map<String, dynamic>;
      final token = data['token'] as String?;
      if (token == null || token.isEmpty) {
        throw Exception('Token invalide');
      }
      // Stocker le token (en mémoire et en persistance)
      await AuthService.setToken(token);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
        );
      }
    } on DioException catch (e) {
      String errorMsg = 'Erreur réseau';
      if (e.response != null) {
        // Erreur HTTP avec réponse
        errorMsg = e.response?.data?['error'] ?? 
                   'Erreur ${e.response?.statusCode}: ${e.response?.statusMessage}';
        debugPrint('[LOGIN] Erreur HTTP: ${e.response?.statusCode} - ${e.response?.data}');
      } else if (e.type == DioExceptionType.connectionTimeout) {
        errorMsg = 'Timeout de connexion. Vérifiez votre connexion Internet.';
        debugPrint('[LOGIN] Timeout de connexion');
      } else if (e.type == DioExceptionType.receiveTimeout) {
        errorMsg = 'Timeout de réception. Le serveur met trop de temps à répondre.';
        debugPrint('[LOGIN] Timeout de réception');
      } else if (e.type == DioExceptionType.connectionError) {
        errorMsg = 'Impossible de se connecter au serveur. Vérifiez l\'URL: ${ApiClient.dio.options.baseUrl}';
        debugPrint('[LOGIN] Erreur de connexion: ${e.message}');
      } else {
        errorMsg = 'Erreur réseau: ${e.message}';
        debugPrint('[LOGIN] Erreur DioException: ${e.type} - ${e.message}');
      }
      if (mounted) {
        setState(() => _error = errorMsg);
      }
    } catch (e) {
      debugPrint('[LOGIN] Erreur inattendue: $e');
      if (mounted) {
        setState(() => _error = 'Erreur: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin — Connexion')),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.admin_panel_settings, size: 80, color: Colors.teal),
                const SizedBox(height: 24),
                const Text('Dashboard Admin', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mot de passe',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  onSubmitted: (_) => _login(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Se connecter'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

