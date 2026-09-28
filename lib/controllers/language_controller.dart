import 'package:flutter/material.dart';
import '../utils/shared_prefs_helper.dart';

class LanguageController extends ChangeNotifier {
  Locale _locale = const Locale('fr');

  Locale get locale => _locale;

  LanguageController() {
    _loadLanguage();
  }

  void _loadLanguage() {
    final savedLang = SharedPrefsHelper.getLanguage();
    if (savedLang != null) {
      _locale = Locale(savedLang);
    }
  }

  Future<void> changeLanguage(String languageCode) async {
    _locale = Locale(languageCode);
    await SharedPrefsHelper.saveLanguage(languageCode);
    notifyListeners();
  }

  bool isLanguageSelected() {
    return SharedPrefsHelper.getLanguage() != null;
  }
}
