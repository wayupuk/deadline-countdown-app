import 'package:deadlines/platform/linux_tray.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads gdbus NameHasOwner output', () {
    expect(statusNotifierWatcherPresent('(true,)\n'), isTrue);
    expect(statusNotifierWatcherPresent('(false,)\n'), isFalse);
    expect(statusNotifierWatcherPresent(''), isFalse);
  });
}
