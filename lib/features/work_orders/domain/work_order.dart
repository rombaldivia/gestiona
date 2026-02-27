import 'work_order_status.dart';

class WorkOrder {
  WorkOrder({
    required this.id,
    required this.sequence,
    required this.year,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.status,
    this.quoteTitle,
    this.quoteId,
    this.quoteSequence,
    this.customerName,
    this.customerPhone,
    this.notes,
    this.steps = const [],
    this.members = const [],
  });

  final String id;
  final int sequence;
  final int year;
  final int createdAtMs;
  final int updatedAtMs;
  final WorkOrderStatus status;

  final String? quoteTitle;      // nombre del proyecto
  final String? quoteId;         // cotización de origen
  final int? quoteSequence;      // número de la cotización
  final String? customerName;
  final String? customerPhone;
  final String? notes;

  final List<WorkOrderStep> steps;
  final List<WorkOrderMember> members;

  double get progress {
    if (steps.isEmpty) return 0;
    return steps.where((s) => s.completed).length / steps.length;
  }

  WorkOrder copyWith({
    String? id,
    int? sequence,
    int? year,
    int? createdAtMs,
    int? updatedAtMs,
    WorkOrderStatus? status,
    String? quoteTitle,
    String? quoteId,
    int? quoteSequence,
    String? customerName,
    String? customerPhone,
    String? notes,
    List<WorkOrderStep>? steps,
    List<WorkOrderMember>? members,
  }) {
    return WorkOrder(
      id: id ?? this.id,
      sequence: sequence ?? this.sequence,
      year: year ?? this.year,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      status: status ?? this.status,
      quoteTitle: quoteTitle ?? this.quoteTitle,
      quoteId: quoteId ?? this.quoteId,
      quoteSequence: quoteSequence ?? this.quoteSequence,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      notes: notes ?? this.notes,
      steps: steps ?? this.steps,
      members: members ?? this.members,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sequence': sequence,
    'year': year,
    'createdAtMs': createdAtMs,
    'updatedAtMs': updatedAtMs,
    'status': status.name,
    'quoteTitle': quoteTitle,
    'quoteId': quoteId,
    'quoteSequence': quoteSequence,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'notes': notes,
    'steps': steps.map((s) => s.toJson()).toList(),
    'members': members.map((m) => m.toJson()).toList(),
  };

  factory WorkOrder.fromJson(Map<String, dynamic> m) {
    int toInt(dynamic v, int fb) =>
        v is num ? v.toInt() : int.tryParse('$v') ?? fb;

    return WorkOrder(
      id: (m['id'] ?? '').toString(),
      sequence: toInt(m['sequence'], 0),
      year: toInt(m['year'], DateTime.now().year),
      createdAtMs: toInt(m['createdAtMs'], 0),
      updatedAtMs: toInt(m['updatedAtMs'], 0),
      status: WorkOrderStatus.fromString(m['status']?.toString()),
      quoteTitle: m['quoteTitle']?.toString(),
      quoteId: m['quoteId']?.toString(),
      quoteSequence: m['quoteSequence'] is num
          ? (m['quoteSequence'] as num).toInt()
          : null,
      customerName: m['customerName']?.toString(),
      customerPhone: m['customerPhone']?.toString(),
      notes: m['notes']?.toString(),
      steps: (m['steps'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(WorkOrderStep.fromJson)
          .toList(),
      members: (m['members'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(WorkOrderMember.fromJson)
          .toList(),
    );
  }
}

// ── Etapa ─────────────────────────────────────────────────────────────────────
class WorkOrderStep {
  WorkOrderStep({
    required this.id,
    required this.title,
    this.completed = false,
    this.completedAtMs,
    this.assignedTo,      // nombre de la persona asignada
    this.qty,             // cantidad del ítem (de cotización)
    this.unit,            // unidad
    this.notes,
  });

  final String id;
  final String title;
  final bool completed;
  final int? completedAtMs;
  final String? assignedTo;
  final double? qty;
  final String? unit;
  final String? notes;

  WorkOrderStep copyWith({
    String? id,
    String? title,
    bool? completed,
    int? completedAtMs,
    String? assignedTo,
    double? qty,
    String? unit,
    String? notes,
  }) {
    return WorkOrderStep(
      id: id ?? this.id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      completedAtMs: completedAtMs ?? this.completedAtMs,
      assignedTo: assignedTo ?? this.assignedTo,
      qty: qty ?? this.qty,
      unit: unit ?? this.unit,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'completed': completed,
    'completedAtMs': completedAtMs,
    'assignedTo': assignedTo,
    'qty': qty,
    'unit': unit,
    'notes': notes,
  };

  factory WorkOrderStep.fromJson(Map<String, dynamic> m) => WorkOrderStep(
    id: (m['id'] ?? '').toString(),
    title: (m['title'] ?? '').toString(),
    completed: m['completed'] == true,
    completedAtMs: m['completedAtMs'] is num
        ? (m['completedAtMs'] as num).toInt()
        : null,
    assignedTo: m['assignedTo']?.toString(),
    qty: m['qty'] is num ? (m['qty'] as num).toDouble() : null,
    unit: m['unit']?.toString(),
    notes: m['notes']?.toString(),
  );
}

// ── Miembro ───────────────────────────────────────────────────────────────────
class WorkOrderMember {
  WorkOrderMember({
    required this.id,
    required this.name,
    this.role,
  });

  final String id;
  final String name;
  final String? role;

  WorkOrderMember copyWith({String? id, String? name, String? role}) {
    return WorkOrderMember(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'role': role,
  };

  factory WorkOrderMember.fromJson(Map<String, dynamic> m) => WorkOrderMember(
    id: (m['id'] ?? '').toString(),
    name: (m['name'] ?? '').toString(),
    role: m['role']?.toString(),
  );
}
