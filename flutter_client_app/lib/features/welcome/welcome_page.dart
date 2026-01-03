import 'package:flutter/material.dart';
import 'dart:ui' as ui; // Pour PlatformDispatcher
import '../../core/lang_service.dart';
import '../../core/strings.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});
  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _isDetecting = true;

  @override
  void initState() {
    super.initState();
    _autoDetectAndNavigate();
  }

  Future<void> _autoDetectAndNavigate() async {
    // Détecter la langue du téléphone
    final deviceLocale = ui.PlatformDispatcher.instance.locale;
    final deviceLang = deviceLocale.languageCode; // 'fr', 'en', 'ar', 'de', 'it', etc.

    // 🆕 Accepter TOUTES les langues détectées !
    // Le serveur se chargera de la traduction ou du fallback
    String lang = deviceLang ?? 'en'; // Utilise la langue détectée, fallback anglais

    // Initialiser la langue
    await LangService.instance.set(lang);

    // Naviguer directement vers le menu
    if (mounted) {
      setState(() => _isDetecting = false);
      Navigator.pushReplacementNamed(context, '/menu');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Afficher un loader pendant la détection
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Orderly', textAlign: TextAlign.center, style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('Les Emirs — Port El Kantaoui', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 32),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(Strings.t('loading') ?? 'Chargement...', style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}


