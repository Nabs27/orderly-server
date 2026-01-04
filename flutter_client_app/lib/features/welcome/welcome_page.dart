import 'package:flutter/material.dart';
import '../../core/lang_service.dart';
import '../../core/strings.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});
  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final langs = const [
    ('fr','Français'),
    ('ar','العربية'),
    ('en','English'),
    ('de','Deutsch'),
    ('it','Italiano'),
  ];

  @override
  void initState() {
    super.initState();
    LangService.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D47A1), // Bleu tunisien foncé
              Color(0xFF1976D2), // Bleu tunisien moyen
              Color(0xFF42A5F5), // Bleu tunisien clair
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),

                      // Logo avec effet de glow
                      Center(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.restaurant,
                            size: 50,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Titre Orderly
                      const Text(
                        'Orderly',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              offset: Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Nom du restaurant
                      const Text(
                        'Les Emirs',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Lieu
                      const Text(
                        'Port El Kantaoui',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Texte de sélection de langue
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          Strings.t('choose_language'),
                          key: ValueKey(LangService.instance.lang),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                offset: Offset(0, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Grille de drapeaux améliorée
                      GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _langCard('fr', '🇫🇷', 'Français'),
                          _langCard('en', '🇬🇧', 'English'),
                          _langCard('ar', '🇹🇳', 'العربية'),
                          _langCard('de', '🇩🇪', 'Deutsch'),
                          _langCard('it', '🇮🇹', 'Italiano'),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Signature en bas
                      const Center(
                        child: Text(
                          'Propulsé par Orderly',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white60,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _langCard(String code, String flag, String label) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () async {
        await LangService.instance.set(code);
        if (!mounted) return;

        // Animation de transition
        Navigator.pushReplacementNamed(context, '/menu');
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withOpacity(0.15),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              flag,
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}


