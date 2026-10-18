import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

// Row classes are renamed so they don't clash with the app's own Group/Deadline models.
@DataClassName('GroupRow')
class Groups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  TextColumn get color => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('DeadlineRow')
class Deadlines extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  DateTimeColumn get dueAt => dateTime()();
  TextColumn get groupId => text().nullable()();
  TextColumn get priority => text().withDefault(const Constant('normal'))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  BoolColumn get reminderEnabled => boolean().withDefault(const Constant(true))();
  IntColumn get reminderHour => integer().withDefault(const Constant(9))();
  IntColumn get reminderMinute => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class OpenResult {
  OpenResult(this.db, this.recoveredFrom);
  final AppDatabase db;

  /// Where an unreadable database file was moved, if that happened.
  final String? recoveredFrom;
}

@DriftDatabase(tables: [Groups, Deadlines])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  DriftDatabaseOptions get options => const DriftDatabaseOptions(storeDateTimeAsText: true);

  static Future<OpenResult> openDefault() async {
    final dir = await getApplicationSupportDirectory();
    return openAt(File(p.join(dir.path, 'deadlines.db')));
  }

  /// Opens [file]; if it isn't a usable database, moves it aside and starts empty.
  static Future<OpenResult> openAt(File file) async {
    await file.parent.create(recursive: true);
    final db = AppDatabase(NativeDatabase(file));
    try {
      await db.customSelect('SELECT count(*) FROM deadlines').get();
      return OpenResult(db, null);
    } catch (_) {
      await db.close();
      final aside = p.join(file.parent.path, 'deadlines.corrupt-${DateTime.now().millisecondsSinceEpoch}.db');
      await file.rename(aside);
      return OpenResult(AppDatabase(NativeDatabase(file)), aside);
    }
  }
}
