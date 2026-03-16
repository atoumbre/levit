import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('LxAsyncComputed staticDeps async error', () async {
    final c1 = LxAsyncComputed(() async { throw 'async_error'; }, staticDeps: true);
    final terminalStatus = await c1.stream.firstWhere((s) => s is LxSuccess || s is LxError);
    expect(terminalStatus.hasError, true);
    expect((terminalStatus as LxError).error, 'async_error');
  });
}
