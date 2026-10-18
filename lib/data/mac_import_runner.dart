import '../core/mac_import.dart';
import 'repository.dart';

/// Imports the SwiftUI Mac app's deadlines. Never throws: any problem reading or parsing the file becomes
/// a notice, so the app always starts and doesn't retry a broken file on every launch.
Future<String?> importMacDeadlines({required Future<String> Function() read, required DeadlineRepository repo}) async {
  try {
    final added = await repo.importDeadlines(parseMacDeadlines(await read(), DateTime.now().toUtc()));
    return added == 0 ? null : 'Imported $added deadline${added == 1 ? '' : 's'} from the Mac app.';
  } catch (_) {
    return "Couldn't read the Mac app's deadlines, so nothing was imported.";
  }
}
