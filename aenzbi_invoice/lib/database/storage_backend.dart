// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class StorageBackend {
  static html.Storage? _storage;
  static final Map<String, String> _memoryFallback = {};
  static bool _usingMemory = false;

  static Future<void> init() async {
    try {
      final storage = html.window.localStorage;
      storage['__test__'] = '1';
      storage.remove('__test__');
      _storage = storage;
      _usingMemory = false;
    } catch (_) {
      _storage = null;
      _usingMemory = true;
    }
  }

  static String? getString(String key) {
    if (_usingMemory) return _memoryFallback[key];
    try {
      return _storage?[key];
    } catch (_) {
      return _memoryFallback[key];
    }
  }

  static void setString(String key, String value) {
    if (_usingMemory) {
      _memoryFallback[key] = value;
      return;
    }
    try {
      _storage?[key] = value;
    } catch (_) {
      _memoryFallback[key] = value;
    }
  }

  static void remove(String key) {
    _memoryFallback.remove(key);
    try {
      _storage?.remove(key);
    } catch (_) {}
  }
}
