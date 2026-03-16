import 'dart:async';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

class TestReactive<T> extends LxVar<T> { TestReactive(super.initial); }

void main() {
  test('LxWorker handles async callbacks', () async {
    final reactive = TestReactive<int>(0);
    bool callbackRun = false;

    final watch = LxWorker(reactive, (val) async {
      await Future.delayed(Duration(milliseconds: 10));
      callbackRun = true;
    });

    reactive.value = 1;
    await Future.delayed(Duration(milliseconds: 100));

    expect(watch.value.isAsync, true);
    expect(watch.value.isProcessing, false);
    expect(watch.value.runCount, 1);
    expect(callbackRun, isTrue);
  });
}
