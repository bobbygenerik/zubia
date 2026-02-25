import 'dart:convert';
import 'package:http/http.dart' as http;

/// REST API service for languages and room management.
class ApiService {
  final String baseUrl;
  final http.Client _client;

  ApiService({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  Future<Map<String, String>> getLanguages() async {
    try {
      final res = await _client.get(Uri.parse('$baseUrl/api/languages'));
      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body);
        return data.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (_) {}
    // Fallback
    return {
      'en': 'English', 'es': 'Spanish', 'fr': 'French',
      'de': 'German', 'zh': 'Chinese', 'ja': 'Japanese',
      'ar': 'Arabic', 'pt': 'Portuguese', 'ru': 'Russian', 'ko': 'Korean',
    };
  }

  Future<Map<String, dynamic>?> registerUser(String name, String language) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/api/users/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'language': language}),
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return null;
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      final res = await _client.get(Uri.parse('$baseUrl/api/users'));
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        return data.cast<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> getThreads(String userId) async {
    try {
      final res = await _client.get(Uri.parse('$baseUrl/api/threads/$userId'));
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        return data.cast<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return [];
  }

  Future<String?> createThread(String user1Id, String user2Id) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/api/threads/new'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user1_id': user1Id, 'user2_id': user2Id}),
      );
      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body);
        return data['id'] as String?;
      }
    } catch (_) {}
    return null;
  }
}
