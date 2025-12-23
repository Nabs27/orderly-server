import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LangService {
  LangService._();
  static final LangService instance = LangService._();

  final ValueNotifier<String> current = ValueNotifier<String>('fr');

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final lng = sp.getString('lang') ?? 'fr';
    current.value = lng;
  }

  Future<void> set(String lang) async {
    current.value = lang;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('lang', lang);
  }

  String get lang => current.value;
}


