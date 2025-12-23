import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'features/menu/menu_page.dart';
import 'features/confirm/confirm_page.dart';
import 'features/bill/bill_page.dart';
import 'features/history/history_page.dart';
import 'features/welcome/welcome_page.dart';
import 'core/api_client.dart';
import 'core/cart_service.dart';
import 'core/lang_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Charger les variables d'environnement
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print('[MAIN] Fichier .env non trouvé, utilisation des valeurs par défaut');
  }
  
  // Initialiser les services
  await LangService.instance.load();
  await CartService.instance.load();
  
  // Configurer l'URL de l'API depuis .env ou utiliser la valeur par défaut
  final apiUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';
  ApiClient.dio.options.baseUrl = apiUrl;
  
  runApp(const ClientApp());
}

class ClientApp extends StatelessWidget {
  const ClientApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Les Emirs - Client',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomePage(),
        '/menu': (context) => const MenuPage(),
        '/history': (context) => const HistoryPage(),
      },
      onGenerateRoute: (settings) {
        final name = settings.name ?? '/';
        
        // Route pour la confirmation de commande
        if (name.startsWith('/confirm/')) {
          final idStr = name.split('/').last;
          // 🆕 CORRECTION : orderId peut être int (ID officiel) ou String (tempId)
          // Si c'est un nombre, utiliser comme int, sinon comme String (tempId)
          final id = int.tryParse(idStr);
          return MaterialPageRoute(
            builder: (_) => ConfirmPage(orderId: id ?? idStr), // int ou String
          );
        }
        
        // Route pour la facture
        if (name.startsWith('/bill/')) {
          final idStr = name.split('/').last;
          final id = int.tryParse(idStr) ?? 0;
          return MaterialPageRoute(
            builder: (_) => BillPage(billId: id),
          );
        }
        
        // Route par défaut
        return MaterialPageRoute(
          builder: (_) => const WelcomePage(),
        );
      },
    );
  }
}
