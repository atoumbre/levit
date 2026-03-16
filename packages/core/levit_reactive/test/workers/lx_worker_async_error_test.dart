import 'dart:async';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

class TestReactive<T> extends LxVar<T> { TestReactive(super.initial); }

void main() {
  test('LxWorker handles async callback error', () async {
    final reactive = TestReactive<int>(0);
    Object? capturedError;

    final watch = LxWorker(reactive, (val) async {
      await Future.delayed(Duration(milliseconds: 10));
      throw 'Async Error';
    }, onProcessingError: (e, s) => capturedError = e);

    reactive.value = 1;
    await Future.delayed(Duration(milliseconds: 50));

    expect(watch.value.runCount, 1);
    expect(capturedError, 'Async Error');
    expect(watch.value.error, 'Async Error');
  });
}
