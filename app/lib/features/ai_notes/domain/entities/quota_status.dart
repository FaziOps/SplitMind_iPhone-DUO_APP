import 'package:equatable/equatable.dart';

/// The user's daily AI allowance as reported by the backend (NFR-5).
class QuotaStatus extends Equatable {
  const QuotaStatus({required this.limit, required this.used, required this.remaining, this.resetsAt});

  final int limit;
  final int used;
  final int remaining;
  final DateTime? resetsAt;

  @override
  List<Object?> get props => [limit, used, remaining, resetsAt];
}
