import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('Global Accessors coverage', () {
    Lx.enterAsyncScope();
    Lx.exitAsyncScope();
    expect(Lx.asyncComputedTrackerZoneKey, isNotNull);
  });
}
