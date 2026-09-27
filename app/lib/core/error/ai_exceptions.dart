/// Typed failures for AI requests. The notes pane renders a distinct error
/// state for each (FR-11).
sealed class AiRequestException implements Exception {
  const AiRequestException(this.message);

  /// Short, user-facing explanation.
  final String message;

  /// Whether a plain retry could succeed.
  bool get isRetryable => true;

  @override
  String toString() => '$runtimeType: $message';
}

/// No connection to the backend.
class NetworkException extends AiRequestException {
  const NetworkException([super.message = "You're offline. Your notes are saved; try again when connected."]);
}

class RequestTimeoutException extends AiRequestException {
  const RequestTimeoutException([super.message = 'The request took too long. Try again.']);
}

/// Daily per-user quota exhausted (NFR-5).
class QuotaExceededException extends AiRequestException {
  const QuotaExceededException({
    this.resetsAt,
    String message = 'Daily AI limit reached. Upgrade or try again tomorrow.',
  }) : super(message);

  final DateTime? resetsAt;

  @override
  bool get isRetryable => false;
}

/// Burst limiter tripped; retry after a short wait.
class RateLimitedException extends AiRequestException {
  const RateLimitedException({this.retryAfter, String message = 'Too many requests. Wait a moment and try again.'})
    : super(message);

  final Duration? retryAfter;
}

/// The provider's safety filter declined the passage.
class SafetyBlockedException extends AiRequestException {
  const SafetyBlockedException([super.message = "The AI couldn't process this passage. Try a different selection."]);

  @override
  bool get isRetryable => false;
}

class UnauthorizedException extends AiRequestException {
  const UnauthorizedException([super.message = 'Your session expired. Try again.']);
}

/// The request itself was rejected (empty text, too long, ...).
class InvalidRequestException extends AiRequestException {
  const InvalidRequestException(super.message);

  @override
  bool get isRetryable => false;
}

/// DR-3: the PDF's permissions forbid extracting text.
class ContentRestrictedException extends AiRequestException {
  const ContentRestrictedException([
    super.message = "This document's permissions don't allow copying text, so it can't be sent to AI.",
  ]);

  @override
  bool get isRetryable => false;
}

class ServerException extends AiRequestException {
  const ServerException([super.message = 'The AI service is unavailable right now.', this.statusCode]);

  final int? statusCode;
}
