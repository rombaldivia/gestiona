import 'package:flutter/material.dart';

enum WorkOrderStatus {
  pending,
  inProgress,
  done,
  delivered;

  String get label => switch (this) {
    WorkOrderStatus.pending    => 'Pendiente',
    WorkOrderStatus.inProgress => 'En proceso',
    WorkOrderStatus.done       => 'Terminado',
    WorkOrderStatus.delivered  => 'Entregado',
  };

  Color get color => switch (this) {
    WorkOrderStatus.pending    => Colors.blueGrey,
    WorkOrderStatus.inProgress => const Color(0xFF2F6DAE),
    WorkOrderStatus.done       => const Color(0xFF1B7A5A),
    WorkOrderStatus.delivered  => const Color(0xFF312E81),
  };

  static WorkOrderStatus fromString(String? v) => switch (v) {
    'inProgress' => WorkOrderStatus.inProgress,
    'done'       => WorkOrderStatus.done,
    'delivered'  => WorkOrderStatus.delivered,
    _            => WorkOrderStatus.pending,
  };
}
