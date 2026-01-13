import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  test('LxWatchStat copyWith coverage', () {
    const stat = LxWatchStat(runCount: 0);

    final s1 = stat.copyWith(runCount: 1);
    expect(s1.runCount, 1);
    expect(s1.toString(), contains('runCount: 1'));

    final s2 = stat.copyWith(
      lastDuration: Duration(seconds: 1),
      totalDuration: Duration(seconds: 1),
      lastRun: DateTime(2023),
      error: 'Err',
      isAsync: true,
      isProcessing: true,
    );

    expect(s2.lastDuration.inSeconds, 1);
    expect(s2.isAsync, true);
    expect(s2.error, 'Err');
  });
}
