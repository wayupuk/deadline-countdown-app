import 'package:intl/intl.dart';

String _year(int gregorian, {required bool buddhist}) => '${buddhist ? gregorian + 543 : gregorian}';
String _time(DateTime d) => DateFormat('HH:mm').format(d);

/// "Sat, 24 Oct at 17:00"; the year is added when it isn't the current one ("Wed, 10 Feb 2570 at 06:59" in BE).
String dueLabel(DateTime due, {required DateTime now, required bool buddhist}) {
  final day = DateFormat('EEE, d MMM').format(due);
  final year = due.year == now.year ? '' : ' ${_year(due.year, buddhist: buddhist)}';
  return '$day$year at ${_time(due)}';
}

/// "Saturday, 24 October 2569 at 17:00".
String dueLabelLong(DateTime due, {required bool buddhist}) =>
    '${DateFormat('EEEE, d MMMM').format(due)} ${_year(due.year, buddhist: buddhist)} at ${_time(due)}';

/// ("October", "2569 BE") for the calendar header.
(String, String) monthTitle(DateTime month, {required bool buddhist}) =>
    (DateFormat('MMMM').format(month), buddhist ? '${month.year + 543} BE' : '${month.year}');
