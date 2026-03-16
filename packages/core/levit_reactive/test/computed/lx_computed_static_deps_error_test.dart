import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('LxComputed staticDeps sync error', () {
    expect(() => LxComputed(() { throw 'sync_error'; }, staticDeps: true), throwsA('sync_error'));
  });
}
