import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('LxWorkerStat equality and toString', () {
    final stat1 = LxWorkerStat(runCount: 1, lastDuration: Duration(seconds: 1));
    expect(stat1.runCount, 1);
    expect(stat1.toString(), contains('runCount: 1'));
  });
}
