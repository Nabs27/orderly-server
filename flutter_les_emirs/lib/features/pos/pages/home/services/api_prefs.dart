import 'package:shared_preferences/shared_preferences.dart';
import '../../../../../core/api_client.dart';

class ApiPrefsService {
  bool useCloudApi = false;
  String apiLocalBaseUrl = 'http://localhost:3000';
  String apiCloudBaseUrl = 'https://orderly-server-production.up.railway.app';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    useCloudApi = prefs.getBool('api_use_cloud') ?? false;
    apiLocalBaseUrl = prefs.getString('api_local_url') ?? 'http://localhost:3000';
    apiCloudBaseUrl = prefs.getString('api_cloud_url') ?? 'https://orderly-server-production.up.railway.app';
    apply();
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('api_use_cloud', useCloudApi);
    await prefs.setString('api_local_url', apiLocalBaseUrl);
    await prefs.setString('api_cloud_url', apiCloudBaseUrl);
  }

  void apply() {
    final target = useCloudApi && apiCloudBaseUrl.isNotEmpty ? apiCloudBaseUrl : apiLocalBaseUrl;
    if (target.isNotEmpty) {
      ApiClient.dio.options.baseUrl = target;
    }
  }

  void toggleMode() {
    useCloudApi = !useCloudApi;
    apply();
  }
}
