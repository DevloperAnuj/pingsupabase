import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String? _password;

  static Future<String> get baseUrl async {
    final prefs = await SharedPreferences.getInstance();
    // Empty string => same-origin: requests hit /api/... on the page's own
    // host and nginx proxies them to the backend container. This is the
    // default for the bundled Coolify deploy (backend is not publicly exposed).
    return prefs.getString('backend_url') ?? '';
  }

  static Future<void> setBackendUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backend_url', url.replaceAll(RegExp(r'/$'), ''));
  }

  static Future<String?> getBackendUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('backend_url');
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_password != null) 'x-master-password': _password!,
  };

  static void setPassword(String pw) {
    _password = pw;
  }

  static void clearPassword() {
    _password = null;
  }

  static bool get hasPassword => _password != null;

  // Health check
  static Future<Map<String, dynamic>> health() async {
    final url = await baseUrl;
    final res = await http.get(Uri.parse('$url/api/health'));
    return jsonDecode(res.body);
  }

  // Unlock vault
  static Future<bool> unlock(String password) async {
    final url = await baseUrl;
    final res = await http.post(
      Uri.parse('$url/api/unlock'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'password': password}),
    );
    if (res.statusCode == 200) {
      setPassword(password);
      return true;
    }
    return false;
  }

  // Lock session
  static Future<void> lock() async {
    final url = await baseUrl;
    await http.post(Uri.parse('$url/api/lock'), headers: _headers);
    clearPassword();
  }

  // Get all clients (masked keys)
  static Future<List<Map<String, dynamic>>> getClients() async {
    final url = await baseUrl;
    final res = await http.get(Uri.parse('$url/api/clients'), headers: _headers);
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load clients: ${res.statusCode}');
  }

  // Get single client (full data for editing)
  static Future<Map<String, dynamic>> getClient(String id) async {
    final url = await baseUrl;
    final res = await http.get(Uri.parse('$url/api/clients/$id'), headers: _headers);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Client not found');
  }

  // Add client
  static Future<void> addClient(Map<String, dynamic> data) async {
    final url = await baseUrl;
    final res = await http.post(
      Uri.parse('$url/api/clients'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (res.statusCode != 200) throw Exception('Failed to add client');
  }

  // Update client
  static Future<void> updateClient(String id, Map<String, dynamic> data) async {
    final url = await baseUrl;
    final res = await http.put(
      Uri.parse('$url/api/clients/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (res.statusCode != 200) throw Exception('Failed to update client');
  }

  // Delete client
  static Future<void> deleteClient(String id) async {
    final url = await baseUrl;
    final res = await http.delete(Uri.parse('$url/api/clients/$id'), headers: _headers);
    if (res.statusCode != 200) throw Exception('Failed to delete client');
  }

  // Get logs
  static Future<List<Map<String, dynamic>>> getLogs() async {
    final url = await baseUrl;
    final res = await http.get(Uri.parse('$url/api/logs'), headers: _headers);
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  // Manual ping one client
  static Future<Map<String, dynamic>> pingClient(String id) async {
    final url = await baseUrl;
    final res = await http.post(Uri.parse('$url/api/ping/$id'), headers: _headers);
    return jsonDecode(res.body);
  }

  // Ping all clients
  static Future<void> pingAll() async {
    final url = await baseUrl;
    await http.post(Uri.parse('$url/api/ping-all'), headers: _headers);
  }
}
