import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

class TestReactive<T> extends LxVar<T> {
  TestReactive(super.initial);
}

void main() {
  test('LxStatus convenience watcher', () {
    final statusRx = TestReactive<LxStatus<int>>(LxIdle());
    String stage = '';

    LxWorker.watchStatus(
      statusRx,
      onIdle: () => stage = 'idle',
      onWaiting: () => stage = 'waiting',
      onSuccess: (v) => stage = 'success $v',
      onError: (e) => stage = 'error $e',
    );

    statusRx.value = LxWaiting();
    expect(stage, 'waiting');
    statusRx.value = LxSuccess(10);
    expect(stage, 'success 10');
    statusRx.value = LxError('fail');
    expect(stage, 'error fail');
  });
}
