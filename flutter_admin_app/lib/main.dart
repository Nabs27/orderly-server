import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'features/admin/admin_login_page.dart';
import 'core/api_client.dart';
import 'core/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Charger les variables d'environnement
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // En mode release, le fichier .env doit exister dans les assets
    // En mode debug, on peut continuer avec les valeurs par défaut
    debugPrint('[MAIN] Fichier .env non trouvé: $e');
  }
  
  // Configurer l'URL de l'API depuis .env
  final apiUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';
  ApiClient.dio.options.baseUrl = apiUrl;
  
  
  // Initialiser le service d'authentification (charge le token depuis SharedPreferences)
  await AuthService.initialize();
  
  // Configurer les interceptors pour ajouter automatiquement le token
  ApiClient.setupInterceptors();
  
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dashboard',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
      ),
      home: const AdminLoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
