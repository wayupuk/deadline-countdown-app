import 'dart:convert';

import 'models.dart';

/// Swift's default `Codable` date strategy: seconds since 2001-01-01 UTC.
final _reference = DateTime.utc(2001);

DateTime _appleDate(Object? v) {
  if (v is! num) throw const FormatException('date is not a number');
  return _reference.add(Duration(microseconds: (v * 1e6).round()));
}

/// Reads the SwiftUI Mac app's `deadlines.json`. Ids are kept; colors are dropped (groups own colors now),
/// so imported deadlines land in "No group". Throws [FormatException] on anything it can't read.
List<Deadline> parseMacDeadlines(String json, DateTime importedAt) {
  final decoded = jsonDecode(json);
  if (decoded is! List) throw const FormatException('expected a list');
  return decoded.map((raw) {
    if (raw is! Map || raw['id'] is! String || raw['title'] is! String) {
      throw const FormatException('bad deadline entry');
    }
    return Deadline(
        id: raw['id'] as String,
        title: raw['title'] as String,
        dueAt: _appleDate(raw['dueDate']),
        notes: raw['notes'] as String? ?? '',
        reminderEnabled: raw['reminderEnabled'] as bool? ?? true,
        reminderHour: raw['reminderHour'] as int? ?? 9,
        reminderMinute: raw['reminderMinute'] as int? ?? 0,
        createdAt: _appleDate(raw['createdAt']),
        updatedAt: importedAt);
  }).toList();
}
