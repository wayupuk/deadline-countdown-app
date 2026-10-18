import '../models.dart';
import 'date_grammar.dart';

enum QuickAddError { empty, noDate, noTitle, inPast, unknownGroup }

class QuickAddResult {
  const QuickAddResult({
    required this.title,
    required this.dueAt,
    required this.hasExplicitTime,
    this.priority,
    this.groupName,
  });

  final String title;
  final DateTime dueAt;

  /// False when only a day was typed; the due time was then set to 23:59.
  final bool hasExplicitTime;

  /// From `!` (high) or `!!` (urgent); null when not given.
  final Priority? priority;

  /// Existing group name matched from `#name` (case-insensitive), in its stored spelling.
  final String? groupName;
}

sealed class QuickAddOutcome {
  const QuickAddOutcome();
}

class QuickAddOk extends QuickAddOutcome {
  const QuickAddOk(this.result);
  final QuickAddResult result;
}

class QuickAddFailed extends QuickAddOutcome {
  const QuickAddFailed(this.error, [this.detail]);
  final QuickAddError error;

  /// For [QuickAddError.unknownGroup]: the name that was typed.
  final String? detail;

  @override
  String toString() => 'QuickAddFailed($error, $detail)';
}

const _connectors = {'on', 'by', 'at', 'due', 'before', 'until', 'till', 'for', 'in'};
final _edgeSeparators = RegExp(r'^[-–—:;,.]+|[-–—:;,.]+$');
final _priorityToken = RegExp(r'(?<!\S)(!{1,2})(?!\S)');
final _groupToken = RegExp(r'(?<!\S)#(\S+)');

/// One line like "Lab report Friday 5pm !! #Physics" → title, due date, priority, group.
QuickAddOutcome parseQuickAdd(String text, DateTime now, {Set<String> groupNames = const {}}) {
  var input = text.trim();
  if (input.isEmpty) return const QuickAddFailed(QuickAddError.empty);

  Priority? priority;
  final p = _priorityToken.firstMatch(input);
  if (p != null) {
    priority = p[1]!.length == 2 ? Priority.urgent : Priority.high;
    input = input.replaceRange(p.start, p.end, ' ');
  }

  String? groupName;
  final g = _groupToken.firstMatch(input);
  if (g != null) {
    final wanted = g[1]!.toLowerCase();
    groupName = groupNames.where((n) => n.toLowerCase() == wanted).firstOrNull;
    if (groupName == null) return QuickAddFailed(QuickAddError.unknownGroup, g[1]);
    input = input.replaceRange(g.start, g.end, ' ');
  }

  final match = findDate(input, now);
  if (match == null) return const QuickAddFailed(QuickAddError.noDate);
  final due = match.hasTime ? match.value : DateTime(match.value.year, match.value.month, match.value.day, 23, 59);

  final title = _cleanTitle(input.replaceRange(match.start, match.end, ' '));
  if (title.isEmpty) return const QuickAddFailed(QuickAddError.noTitle);
  if (!due.isAfter(now)) return const QuickAddFailed(QuickAddError.inPast);
  return QuickAddOk(QuickAddResult(
      title: title, dueAt: due, hasExplicitTime: match.hasTime, priority: priority, groupName: groupName));
}

/// Drops standalone separators and connector words at the ends; inner punctuation stays ("Dr. Smith, follow-up").
String _cleanTitle(String raw) {
  final words = raw.split(RegExp(r'\s+')).where((w) => w.replaceAll(_edgeSeparators, '').isNotEmpty).toList();
  bool isConnector(String w) => _connectors.contains(w.toLowerCase().replaceAll(_edgeSeparators, ''));
  while (words.isNotEmpty && isConnector(words.last)) {
    words.removeLast();
  }
  while (words.isNotEmpty && isConnector(words.first)) {
    words.removeAt(0);
  }
  return words.join(' ').replaceAll(_edgeSeparators, '').trim();
}
