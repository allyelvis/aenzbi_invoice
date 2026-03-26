// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';

class ApiClient {
  static const String _base = '/api';

  static Future<dynamic> get(String path) async {
    final req = await html.HttpRequest.request('$_base$path', method: 'GET');
    final text = req.responseText ?? '[]';
    return jsonDecode(text);
  }

  static Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final req = await html.HttpRequest.request(
      '$_base$path',
      method: 'POST',
      requestHeaders: {'Content-Type': 'application/json'},
      sendData: jsonEncode(body),
    );
    final text = req.responseText ?? '{}';
    if (text.isEmpty) return {};
    return jsonDecode(text);
  }

  static Future<void> delete(String path) async {
    await html.HttpRequest.request('$_base$path', method: 'DELETE');
  }
}
