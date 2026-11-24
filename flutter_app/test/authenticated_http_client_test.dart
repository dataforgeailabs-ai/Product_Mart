import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:hotel_supply_flutter/config/api_config.dart';
import 'package:hotel_supply_flutter/services/authenticated_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthenticatedHttpClient', () {
    late FlutterSecureStorage storage;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({
        'access_token': 'old-access',
        'refresh_token': 'old-refresh',
      });
      storage = const FlutterSecureStorage();
    });

    test('refreshes once and replays method, query, headers, and body', () async {
      final observed = <http.Request>[];
      var refreshCount = 0;
      final client = AuthenticatedHttpClient(
        storage: storage,
        innerClient: MockClient((request) async {
          if (request.url.path == Uri.parse(ApiConfig.refreshToken).path) {
            refreshCount++;
            expect(jsonDecode(request.body), {'refresh': 'old-refresh'});
            return http.Response(
              jsonEncode({'access': 'new-access', 'refresh': 'new-refresh'}),
              200,
            );
          }
          observed.add(request);
          if (request.headers['authorization'] == 'Bearer old-access') {
            return http.Response('expired', 401);
          }
          return http.Response('ok', 200);
        }),
      );

      final response = await client.patch(
        Uri.parse('https://example.test/protected/?page=3'),
        headers: const {'Content-Type': 'application/json', 'X-Trace': 'abc'},
        body: jsonEncode({'quantity': 2}),
      );

      expect(response.statusCode, 200);
      expect(refreshCount, 1);
      expect(observed, hasLength(2));
      expect(observed[0].method, 'PATCH');
      expect(observed[1].method, 'PATCH');
      expect(observed[1].url.queryParameters['page'], '3');
      expect(observed[1].headers['authorization'], 'Bearer new-access');
      expect(observed[1].headers['x-trace'], 'abc');
      expect(observed[1].body, jsonEncode({'quantity': 2}));
      expect(await storage.read(key: 'access_token'), 'new-access');
      expect(await storage.read(key: 'refresh_token'), 'new-refresh');
      client.close();
    });

    test('parallel expired requests share one refresh', () async {
      var refreshCount = 0;
      final refreshStarted = Completer<void>();
      final client = AuthenticatedHttpClient(
        storage: storage,
        innerClient: MockClient((request) async {
          if (request.url.path == Uri.parse(ApiConfig.refreshToken).path) {
            refreshCount++;
            if (!refreshStarted.isCompleted) refreshStarted.complete();
            await Future<void>.delayed(const Duration(milliseconds: 30));
            return http.Response(jsonEncode({'access': 'new-access'}), 200);
          }
          if (request.headers['authorization'] == 'Bearer old-access') {
            return http.Response('expired', 401);
          }
          return http.Response('ok', 200);
        }),
      );

      final first = client.get(Uri.parse('https://example.test/one/'));
      final second = client.get(Uri.parse('https://example.test/two/'));
      await refreshStarted.future;
      final responses = await Future.wait([first, second]);

      expect(responses.map((response) => response.statusCode), [200, 200]);
      expect(refreshCount, 1);
      client.close();
    });

    test('rejected refresh clears both tokens and expires session once', () async {
      var expiryCount = 0;
      final client = AuthenticatedHttpClient(
        storage: storage,
        onSessionExpired: () async => expiryCount++,
        innerClient: MockClient((request) async {
          if (request.url.path == Uri.parse(ApiConfig.refreshToken).path) {
            return http.Response('invalid refresh', 401);
          }
          return http.Response('expired', 401);
        }),
      );

      final response = await client.get(
        Uri.parse('https://example.test/protected/'),
      );

      expect(response.statusCode, 401);
      expect(await storage.read(key: 'access_token'), isNull);
      expect(await storage.read(key: 'refresh_token'), isNull);
      expect(expiryCount, 1);
      client.close();
    });

    test('multipart request can be replayed after refresh', () async {
      final bodies = <String>[];
      final contentTypes = <String?>[];
      final client = AuthenticatedHttpClient(
        storage: storage,
        innerClient: MockClient((request) async {
          if (request.url.path == Uri.parse(ApiConfig.refreshToken).path) {
            return http.Response(jsonEncode({'access': 'new-access'}), 200);
          }
          bodies.add(request.body);
          contentTypes.add(request.headers['content-type']);
          if (request.headers['authorization'] == 'Bearer old-access') {
            return http.Response('expired', 401);
          }
          return http.Response('uploaded', 200);
        }),
      );
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://example.test/upload/'),
      )..fields['name'] = 'sample';

      final response = await client.send(request);

      expect(response.statusCode, 200);
      expect(bodies, hasLength(2));
      expect(bodies[1], bodies[0]);
      expect(contentTypes[0], startsWith('multipart/form-data; boundary='));
      expect(contentTypes[1], contentTypes[0]);
      client.close();
    });

    test('login endpoint bypasses token requirement and refresh', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final storageWithoutTokens = const FlutterSecureStorage();
      var sent = false;
      final client = AuthenticatedHttpClient(
        storage: storageWithoutTokens,
        innerClient: MockClient((request) async {
          sent = true;
          expect(request.url.path, Uri.parse(ApiConfig.login).path);
          expect(request.headers.containsKey('authorization'), isFalse);
          return http.Response('{}', 200);
        }),
      );

      final response = await client.post(Uri.parse(ApiConfig.login));

      expect(response.statusCode, 200);
      expect(sent, isTrue);
      client.close();
    });
  });
}
