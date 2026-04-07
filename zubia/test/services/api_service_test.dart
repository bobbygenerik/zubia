import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zubia/services/api_service.dart';

void main() {
  group('ApiService', () {
    const baseUrl = 'http://test.com';

    test('registerUser success', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), '$baseUrl/api/users/register');
        expect(request.method, 'POST');
        expect(request.headers['Content-Type'], 'application/json');
        final body = jsonDecode(request.body);
        expect(body['name'], 'TestUser');
        expect(body['language'], 'en');

        return http.Response(
          jsonEncode({'id': '123', 'name': 'TestUser', 'language': 'en'}),
          200,
        );
      });

      final apiService = ApiService(baseUrl: baseUrl, client: client);
      final result = await apiService.registerUser('TestUser', 'en');

      expect(result, isNotNull);
      expect(result!['id'], '123');
      expect(result['name'], 'TestUser');
      expect(result['language'], 'en');
    });

    test('registerUser failure', () async {
      final client = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final apiService = ApiService(baseUrl: baseUrl, client: client);
      final result = await apiService.registerUser('TestUser', 'en');

      expect(result, isNull);
    });

    test('registerUser exception', () async {
      final client = MockClient((request) async {
        throw http.ClientException('Network error');
      });

      final apiService = ApiService(baseUrl: baseUrl, client: client);
      final result = await apiService.registerUser('TestUser', 'en');

      expect(result, isNull);
    });

    test('createThread success', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), '$baseUrl/api/threads');
        expect(request.method, 'POST');
        expect(request.headers['Content-Type'], 'application/json');
        final body = jsonDecode(request.body);
        expect(body['user1_id'], 'u1');
        expect(body['user2_id'], 'u2');

        return http.Response(jsonEncode({'id': 'thread_123'}), 200);
      });

      final apiService = ApiService(baseUrl: baseUrl, client: client);
      final result = await apiService.createThread('u1', 'u2');

      expect(result, isNotNull);
      expect(result, 'thread_123');
    });

    test('createThread failure', () async {
      final client = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final apiService = ApiService(baseUrl: baseUrl, client: client);
      final result = await apiService.createThread('u1', 'u2');

      expect(result, isNull);
    });

    test('createThread exception', () async {
      final client = MockClient((request) async {
        throw http.ClientException('Network error');
      });

      final apiService = ApiService(baseUrl: baseUrl, client: client);
      final result = await apiService.createThread('u1', 'u2');

      expect(result, isNull);
    });
  });
}
