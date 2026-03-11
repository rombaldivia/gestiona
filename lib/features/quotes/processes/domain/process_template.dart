import '../../domain/quote_step.dart';
import 'process_requirement.dart';

class ProcessTemplate {
  ProcessTemplate({
    required this.id,
    required this.name,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.steps,
    required this.requirements,
  });

  final String id;
  final String name;
  final int createdAtMs;
  final int updatedAtMs;

  /// Pasos del proceso
  final List<QuoteProcessStep> steps;

  /// Ítems del inventario requeridos para este proceso
  final List<ProcessRequirement> requirements;

  ProcessTemplate copyWith({
    String? id,
    String? name,
    int? createdAtMs,
    int? updatedAtMs,
    List<QuoteProcessStep>? steps,
    List<ProcessRequirement>? requirements,
  }) {
    return ProcessTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      steps: steps ?? this.steps,
      requirements: requirements ?? this.requirements,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAtMs': createdAtMs,
    'updatedAtMs': updatedAtMs,
    'steps': steps.map((e) => e.toJson()).toList(),
    'requirements': requirements.map((e) => e.toJson()).toList(),
  };

  factory ProcessTemplate.fromJson(Map<String, dynamic> m) {
    int toIntSafe(dynamic v, int fallback) =>
        v is num ? v.toInt() : int.tryParse('$v') ?? fallback;

    final steps = (m['steps'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(QuoteProcessStep.fromJson)
        .toList();

    final reqs = (m['requirements'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(ProcessRequirement.fromJson)
        .toList();

    return ProcessTemplate(
      id: (m['id'] ?? '').toString(),
      name: (m['name'] ?? '').toString(),
      createdAtMs: toIntSafe(m['createdAtMs'], 0),
      updatedAtMs: toIntSafe(m['updatedAtMs'], 0),
      steps: steps,
      requirements: reqs,
    );
  }
}
