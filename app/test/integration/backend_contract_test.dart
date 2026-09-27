// Runs the app's real network stack against a live backend. Opt-in:
//
//   (cd backend && npm start)
//   SPLITMIND_BACKEND_URL=http://localhost:8787 flutter test test/integration
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:splitmind/core/error/ai_exceptions.dart';
import 'package:splitmind/core/network/auth_token_store.dart';
import 'package:splitmind/core/network/backend_api_client.dart';
import 'package:splitmind/features/ai_notes/data/sources/backend_proxy_data_source.dart';
import 'package:splitmind/features/workspace/domain/entities/synthesis_action.dart';

void main() {
  final baseUrl = Platform.environment['SPLITMIND_BACKEND_URL'];
  final skip = baseUrl == null ? 'Set SPLITMIND_BACKEND_URL to run against a live backend' : null;

  late BackendProxyDataSource source;
  setUp(() {
    source = BackendProxyDataSource(
      BackendApiClient(httpClient: http.Client(), tokenStore: InMemoryAuthTokenStore(), baseUrl: baseUrl ?? ''),
    );
  });

  test(
    'synthesizes every action as Markdown and reports quota',
    () async {
      for (final action in SynthesisAction.values) {
        final text =
            'Contract check for ${action.name} at ${DateTime.now().microsecondsSinceEpoch}. It has two sentences.';
        final result = await source.synthesize(
          text: text,
          action: action,
          question: action.requiresQuestion ? 'What does this passage check?' : null,
          docId: 'contract',
          page: 1,
        );
        expect(result.markdown.trim(), isNotEmpty, reason: action.name);
        expect(result.quota, isNotNull);
        // Stay under the backend's burst limiter.
        await Future<void>.delayed(const Duration(milliseconds: 1100));
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('rejects an empty passage with a typed error', () async {
    await expectLater(
      source.synthesize(text: '   ', action: SynthesisAction.explain),
      throwsA(isA<InvalidRequestException>()),
    );
  }, skip: skip);
}
