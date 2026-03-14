// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class StorageBackend {
  static html.Storage? _storage;

  static Future<void> init() async {
    _storage = html.window.localStorage;
  }

  static String? getString(String key) {
    return _storage?[key];
  }

  static void setString(String key, String value) {
    _storage?[key] = value;
  }

  static void remove(String key) {
    _storage?.remove(key);
  }
}
