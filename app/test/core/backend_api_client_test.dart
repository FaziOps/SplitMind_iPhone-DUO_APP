import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:splitmind/core/error/ai_exceptions.dart';
import 'package:splitmind/core/network/auth_token_store.dart';
import 'package:splitmind/core/network/backend_api_client.dart';
import 'package:splitmind/features/ai_notes/data/sources/backend_proxy_data_source.dart';
import 'package:splitmind/features/workspace/domain/entities/synthesis_action.dart';

http.Response _json(int status, Object body) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  BackendProxyDataSource sourceWith(MockClientHandler handler, {AuthTokenStore? tokens}) => BackendProxyDataSource(
    BackendApiClient(
      httpClient: MockClient(handler),
      tokenStore: tokens ?? InMemoryAuthTokenStore(),
      baseUrl: 'http://api.test',
    ),
  );

  Future<void> synth(BackendProxyDataSource s) => s.synthesize(text: 'Hello.', action: SynthesisAction.explain);

  test('signs in anonymously, then sends the bearer token and request body', () async {
    final seen = <http.Request>[];
    final source = sourceWith((req) async {
      seen.add(req);
      if (req.url.path == '/v1/auth/anonymous') return _json(200, {'token': 't1'});
      return _json(200, {
        'markdown': '### Explanation\nok',
        'quota': {'limit': 200, 'used': 5, 'remaining': 195, 'resetsAt': '2026-09-27T00:00:00.000Z'},
      });
    });

    final result = await source.synthesize(text: 'Hello.', action: SynthesisAction.explain, docId: 'd', page: 4);

    expect(seen.map((r) => r.url.path), ['/v1/auth/anonymous', '/v1/synthesize']);
    expect(seen.last.headers['Authorization'], 'Bearer t1');
    expect(jsonDecode(seen.last.body), {'text': 'Hello.', 'action': 'explain', 'docId': 'd', 'page': 4});
    expect(result.quota?.remaining, 195);
  });

  test('sends the question only for actions that take one', () async {
    final bodies = <Object?>[];
    final source = sourceWith((req) async {
      if (req.url.path == '/v1/auth/anonymous') return _json(200, {'token': 't1'});
      bodies.add(jsonDecode(req.body));
      return _json(200, {'markdown': '### Answer\nok'});
    });

    await source.synthesize(text: 'Hello.', action: SynthesisAction.ask, question: 'Why?');

    expect(bodies.single, {'text': 'Hello.', 'action': 'ask', 'question': 'Why?', 'docId': null, 'page': null});
  });

  test('re-authenticates once on 401', () async {
    final tokens = InMemoryAuthTokenStore();
    await tokens.write('stale');
    var synthCalls = 0;
    final source = sourceWith((req) async {
      if (req.url.path == '/v1/auth/anonymous') return _json(200, {'token': 'fresh'});
      synthCalls++;
      if (req.headers['Authorization'] == 'Bearer stale') return _json(401, {'error': 'unauthorized'});
      return _json(200, {'markdown': 'ok'});
    }, tokens: tokens);

    await synth(source);
    expect(synthCalls, 2);
    expect(await tokens.read(), 'fresh');
  });

  final cases = <String, (http.Response, TypeMatcher<AiRequestException>)>{
    'quota': (_json(429, {'error': 'quota_exceeded'}), isA<QuotaExceededException>()),
    'burst': (_json(429, {'error': 'rate_limited', 'retryAfterMs': 900}), isA<RateLimitedException>()),
    'safety': (_json(422, {'error': 'safety_blocked'}), isA<SafetyBlockedException>()),
    'too long': (_json(413, {'error': 'text_too_long', 'message': 'Too long'}), isA<InvalidRequestException>()),
    'timeout': (_json(504, {'error': 'upstream_timeout'}), isA<RequestTimeoutException>()),
    'server': (http.Response('oops', 500), isA<ServerException>()),
  };
  cases.forEach((name, spec) {
    test('maps $name responses to typed exceptions', () async {
      final tokens = InMemoryAuthTokenStore();
      await tokens.write('t');
      final source = sourceWith((_) async => spec.$1, tokens: tokens);
      await expectLater(synth(source), throwsA(spec.$2));
    });
  });

  test('transport failures become NetworkException', () async {
    final source = sourceWith((_) async => throw http.ClientException('offline'));
    await expectLater(synth(source), throwsA(isA<NetworkException>()));
  });
}
