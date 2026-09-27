import '../../../../core/error/ai_exceptions.dart';
import '../../../../core/network/backend_api_client.dart';
import '../../../workspace/domain/entities/synthesis_action.dart';
import '../models/synthesis_response_model.dart';

/// Calls the SplitMind backend, never an AI provider directly (NFR-2). The
/// backend holds the model key, enforces quotas (NFR-5) and returns Markdown.
///
/// Contract: `POST /v1/synthesize` with `{text, action, question?, docId, page}`.
class BackendProxyDataSource {
  const BackendProxyDataSource(this._client);

  final BackendApiClient _client;

  Future<SynthesisResponseModel> synthesize({
    required String text,
    required SynthesisAction action,
    String? question,
    String? docId,
    int? page,
  }) async {
    final json = await _client.postJson('/v1/synthesize', {
      'text': text,
      'action': action.name,
      'question': ?question,
      'docId': docId,
      'page': page,
    });
    try {
      return SynthesisResponseModel.fromJson(json);
    } on FormatException {
      throw const ServerException('The AI service returned an unexpected response.');
    }
  }
}
