enum Priority { low, normal, high, urgent }

enum DeadlineColor { blue, purple, pink, red, orange, yellow, green, teal, graphite }

/// How much detail compact countdowns show: "79d", "79d 1h", "79d 1h 23m".
enum CountdownPrecision {
  days(1),
  hours(2),
  minutes(3);

  const CountdownPrecision(this.unitCount);
  final int unitCount;
}

class Group {
  Group({
    required this.id,
    required this.name,
    required this.color,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String name;
  final DeadlineColor color;
  final int sortOrder;
  final DateTime createdAt, updatedAt;
  final DateTime? deletedAt;

  Group copyWith({String? name, DeadlineColor? color, int? sortOrder, DateTime? updatedAt, DateTime? deletedAt}) => Group(
      id: id,
      name: name ?? this.name,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt);
}

class Deadline {
  Deadline({
    required this.id,
    required this.title,
    required this.dueAt,
    this.groupId,
    this.priority = Priority.normal,
    this.notes = '',
    this.reminderEnabled = true,
    this.reminderHour = 9,
    this.reminderMinute = 0,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String title;
  final DateTime dueAt;
  final String? groupId;
  final Priority priority;
  final String notes;
  final bool reminderEnabled;

  /// Daily reminder time, local wall clock.
  final int reminderHour, reminderMinute;
  final DateTime createdAt, updatedAt;

  /// Soft delete marker, kept so a later sync can propagate deletions.
  final DateTime? deletedAt;

  bool isOverdue(DateTime now) => !dueAt.isAfter(now);

  /// Elapsed share of createdAt…dueAt, clamped to 0…1.
  double progress(DateTime now) {
    final total = dueAt.difference(createdAt).inMicroseconds;
    if (total <= 0) return 1;
    return (now.difference(createdAt).inMicroseconds / total).clamp(0.0, 1.0);
  }

  /// [groupId] uses a sentinel so callers can set it to null ("No group").
  Deadline copyWith({
    String? title,
    DateTime? dueAt,
    Object? groupId = _keep,
    Priority? priority,
    String? notes,
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) =>
      Deadline(
          id: id,
          title: title ?? this.title,
          dueAt: dueAt ?? this.dueAt,
          groupId: identical(groupId, _keep) ? this.groupId : groupId as String?,
          priority: priority ?? this.priority,
          notes: notes ?? this.notes,
          reminderEnabled: reminderEnabled ?? this.reminderEnabled,
          reminderHour: reminderHour ?? this.reminderHour,
          reminderMinute: reminderMinute ?? this.reminderMinute,
          createdAt: createdAt,
          updatedAt: updatedAt ?? this.updatedAt,
          deletedAt: deletedAt ?? this.deletedAt);
}

const _keep = Object();
