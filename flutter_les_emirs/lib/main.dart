import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'features/menu/menu_page.dart';
import 'features/confirm/confirm_page.dart';
import 'features/bill/bill_page.dart';
import 'features/services/services_page.dart';
import 'features/history/history_page.dart';
import 'features/welcome/welcome_page.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/admin/admin_login_page.dart';
import 'features/pos/pos_login_page.dart';
import 'features/pos/pages/home/PosHomePage_refactor.dart' as refHome;
import 'features/pos/pages/order/PosOrderPage_refactor.dart';
import 'features/pos/pos_invoice_viewer_page.dart';
import 'core/api_client.dart';
import 'core/cart_service.dart';
import 'package:flutter_window_close/flutter_window_close.dart';

// Permet de choisir la page initiale au build: --dart-define=INITIAL_ROUTE=/dashboard
const String kInitialRoute = String.fromEnvironment('INITIAL_ROUTE', defaultValue: '/pos_refactor');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print('[MAIN] Fichier .env non trouvé, utilisation des valeurs par défaut');
  }
  // Reset local cart/history at each app start (facilite les tests)
  try {
    // vider le panier local
    await CartService.instance.clear();
    CartService.instance.lastOrderId = null;
    CartService.instance.lastOrderTotal = null;
    CartService.instance.lastOrderAt = null;
    await CartService.instance.save();
  } catch (_) {}
  // 🖼️ Intercepter la fermeture de la fenêtre (Windows/Mac/Linux uniquement, pas sur Web)
  if (!kIsWeb) {
    try {
      FlutterWindowClose.setWindowShouldCloseHandler(() async {
        // Afficher une boîte de dialogue de confirmation
        final shouldClose = await showDialog<bool>(
          context: navigatorKey.currentContext!,
          builder: (context) {
            return AlertDialog(
              title: const Text('Quitter l\'application ?'),
              content: const Text('Êtes-vous sûr de vouloir fermer le POS ?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Quitter'),
                ),
              ],
            );
          },
        );
        return shouldClose ?? false; // false = empêcher la fermeture
      });
    } catch (e) {
      // Ignorer les erreurs si le package n'est pas disponible
      print('[MAIN] FlutterWindowClose non disponible: $e');
    }
  }

  runApp(const MyApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Les Emirs',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      initialRoute: kInitialRoute,
      onGenerateRoute: (settings) {
        final name = settings.name ?? '/';
        if (name == '/') {
          return MaterialPageRoute(builder: (_) => const WelcomePage());
        }
        if (name == '/menu') {
          return MaterialPageRoute(builder: (_) => const MenuPage());
        }
        if (name.startsWith('/confirm/')) {
          final idStr = name.split('/').last;
          final id = int.tryParse(idStr) ?? 0;
          return MaterialPageRoute(builder: (_) => ConfirmPage(orderId: id));
        }
        if (name.startsWith('/bill/')) {
          final idStr = name.split('/').last;
          final id = int.tryParse(idStr) ?? 0;
          return MaterialPageRoute(builder: (_) => BillPage(billId: id));
        }
        if (name == '/services') {
          return MaterialPageRoute(builder: (_) => const ServicesPage());
        }
        if (name == '/dashboard') {
          return MaterialPageRoute(builder: (_) => const DashboardPage());
        }
        if (name == '/history') {
          return MaterialPageRoute(builder: (_) => const HistoryPage());
        }
        if (name == '/admin') {
          return MaterialPageRoute(builder: (_) => const AdminLoginPage());
        }
        if (name == '/pos') {
          return MaterialPageRoute(builder: (_) => const PosOrderPage());
        }
        if (name == '/pos_refactor') {
          return MaterialPageRoute(builder: (ctx) {
            final args = (ModalRoute.of(ctx)?.settings.arguments);
            String? selected;
            if (args is Map) {
              final map = args.cast<String, dynamic>();
              selected = map['selectedServer'] as String?;
            }
            return refHome.PosHomePage(selectedServer: selected);
          });
        }
        return MaterialPageRoute(builder: (_) => const MenuPage());
      },
    );
  }
}
