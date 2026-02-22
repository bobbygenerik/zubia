import 'dart:convert';
import 'package:http/http.dart' as http;

/// REST API service for languages and room management.
class ApiService {
  final String baseUrl;

  ApiService({required this.baseUrl});

  Future<Map<String, String>> getLanguages() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/languages'));
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

  Future<List<Map<String, dynamic>>> getRooms() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/rooms'));
      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body);
        return data.values.cast<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> createRoom(String name) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/rooms'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name}),
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return null;
  }
}
