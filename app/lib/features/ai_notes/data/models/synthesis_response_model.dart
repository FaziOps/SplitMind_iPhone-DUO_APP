import '../../domain/entities/quota_status.dart';

/// JSON body of `POST /v1/synthesize`.
class SynthesisResponseModel {
  const SynthesisResponseModel({required this.markdown, this.quota});

  factory SynthesisResponseModel.fromJson(Map<String, dynamic> json) {
    final markdown = json['markdown'];
    if (markdown is! String || markdown.trim().isEmpty) {
      throw const FormatException('Response has no markdown');
    }
    final quota = json['quota'];
    return SynthesisResponseModel(
      markdown: markdown,
      quota: quota is Map<String, dynamic> ? quotaFromJson(quota) : null,
    );
  }

  final String markdown;
  final QuotaStatus? quota;

  static QuotaStatus quotaFromJson(Map<String, dynamic> json) => QuotaStatus(
    limit: (json['limit'] as num?)?.toInt() ?? 0,
    used: (json['used'] as num?)?.toInt() ?? 0,
    remaining: (json['remaining'] as num?)?.toInt() ?? 0,
    resetsAt: json['resetsAt'] is String ? DateTime.tryParse(json['resetsAt'] as String) : null,
  );
}
