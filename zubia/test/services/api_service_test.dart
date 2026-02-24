import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zubia/services/api_service.dart';

void main() {
  group('ApiService', () {
    const String baseUrl = 'https://example.com';

    // Fallback languages to verify against
    final fallbackLanguages = {
      'en': 'English',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'zh': 'Chinese',
      'ja': 'Japanese',
      'ar': 'Arabic',
      'pt': 'Portuguese',
      'ru': 'Russian',
      'ko': 'Korean',
    };

    test('getLanguages makes correct HTTP request', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), '$baseUrl/api/languages');
        expect(request.method, 'GET');
        return http.Response(jsonEncode({'en': 'English'}), 200);
      });

      final apiService = ApiService(baseUrl: baseUrl, client: client);
      await apiService.getLanguages();
    });

    test('getLanguages returns languages on 200 OK', () async {
      final mockResponse = {'en': 'English', 'es': 'Spanish'};
      final client = MockClient((request) async {
        return http.Response(jsonEncode(mockResponse), 200);
      });

      final apiService = ApiService(baseUrl: baseUrl, client: client);
      final result = await apiService.getLanguages();

      expect(result, mockResponse);
    });

    test('getLanguages returns fallback on 404', () async {
      final client = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final apiService = ApiService(baseUrl: baseUrl, client: client);
      final result = await apiService.getLanguages();

      expect(result, fallbackLanguages);
    });

    test('getLanguages returns fallback on exception', () async {
      final client = MockClient((request) async {
        throw Exception('Network error');
      });

      final apiService = ApiService(baseUrl: baseUrl, client: client);
      final result = await apiService.getLanguages();

      expect(result, fallbackLanguages);
    });
  });
}
