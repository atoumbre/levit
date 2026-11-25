import 'package:test/test.dart';
import 'package:levit_reactive/spi.dart';

void main() {
  test('async scopes expose their computation tracker zone key', () {
    LxSpi.enterAsyncScope();
    LxSpi.exitAsyncScope();
    expect(LxSpi.asyncComputedTrackerZoneKey, isNotNull);
  });
}
