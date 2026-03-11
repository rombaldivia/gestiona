enum QuoteStepStatus { todo, doing, done, blocked }

extension QuoteStepStatusX on QuoteStepStatus {
  String get label => switch (this) {
    QuoteStepStatus.todo => 'Pendiente',
    QuoteStepStatus.doing => 'En proceso',
    QuoteStepStatus.done => 'Hecho',
    QuoteStepStatus.blocked => 'Bloqueado',
  };

  static QuoteStepStatus fromString(String? s) {
    final v = (s ?? '').toLowerCase().trim();
    for (final e in QuoteStepStatus.values) {
      if (e.name == v) return e;
    }
    return QuoteStepStatus.todo;
  }
}

class QuoteProcessStep {
  QuoteProcessStep({
    required this.stepId,
    required this.title,
    required this.status,
    this.note,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  final String stepId;
  final String title;
  final QuoteStepStatus status;
  final String? note;

  final int createdAtMs;
  final int updatedAtMs;

  QuoteProcessStep copyWith({
    String? stepId,
    String? title,
    QuoteStepStatus? status,
    String? note,
    int? createdAtMs,
    int? updatedAtMs,
  }) {
    return QuoteProcessStep(
      stepId: stepId ?? this.stepId,
      title: title ?? this.title,
      status: status ?? this.status,
      note: note ?? this.note,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, dynamic> toJson() => {
    'stepId': stepId,
    'title': title,
    'status': status.name,
    'note': note,
    'createdAtMs': createdAtMs,
    'updatedAtMs': updatedAtMs,
  };

  factory QuoteProcessStep.fromJson(Map<String, dynamic> m) {
    int toIntSafe(dynamic v, int fallback) =>
        v is num ? v.toInt() : int.tryParse('$v') ?? fallback;

    return QuoteProcessStep(
      stepId: (m['stepId'] ?? '').toString(),
      title: (m['title'] ?? '').toString(),
      status: QuoteStepStatusX.fromString(m['status']?.toString()),
      note: m['note']?.toString(),
      createdAtMs: toIntSafe(m['createdAtMs'], 0),
      updatedAtMs: toIntSafe(m['updatedAtMs'], 0),
    );
  }
}
