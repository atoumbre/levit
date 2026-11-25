import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('async scopes expose their computation tracker zone key', () {
    Lx.enterAsyncScope();
    Lx.exitAsyncScope();
    expect(Lx.asyncComputedTrackerZoneKey, isNotNull);
  });
}
