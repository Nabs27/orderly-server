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
  ];

  @override
  void initState() {
    super.initState();
    LangService.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    // Logo / nom app
                    const Text('Orderly', textAlign: TextAlign.center, style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    const Text('Les Emirs — Port El Kantaoui', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 28),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (c,a)=> FadeTransition(opacity: a, child: c),
                      child: Text(Strings.t('choose_language'), key: ValueKey(LangService.instance.lang), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 12),
                    // Grille de drapeaux
                    GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _langCard('fr', '🇫🇷', 'Français'),
                        _langCard('en', '🇬🇧', 'English'),
                        _langCard('ar', '🇹🇳', 'العربية'),
                        _langCard('de', '🇩🇪', 'Deutsch'),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _langCard(String code, String flag, String label) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        await LangService.instance.set(code);
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/menu');
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surface,
          boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black12)],
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(flag, style: const TextStyle(fontSize: 42)),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}


