import 'dart:async';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

class DepGraphCapture extends LevitReactiveMiddleware {
  LxReactive? capturedComputed;
  List<LxReactive>? capturedDeps;
  @override
  void Function(LxReactive, List<LxReactive>)? get onGraphChange =>
      (computed, dependencies) {
        capturedComputed = computed;
        capturedDeps = dependencies;
      };
}

void main() {
  test('Async Computed triggers onDependencyGraphChange', () async {
    final capture = DepGraphCapture();
    Lx.addMiddleware(capture);
    addTearDown(() => Lx.removeMiddleware(capture));

    final count = 20.lx;
    final completer = Completer<int>();

    final asyncComp = LxComputed.async(() async {
      return await completer.future + count.value;
    });

    void listener() {}
    asyncComp.addListener(listener);

    expect(asyncComp.value, isA<LxWaiting>());
    completer.complete(5);
    await Future.delayed(Duration.zero);

    expect(asyncComp.value, isA<LxSuccess>());
    expect(asyncComp.value.valueOrNull, 25);
    expect(capture.capturedComputed, equals(asyncComp));
    expect(capture.capturedDeps, contains(count));

    asyncComp.removeListener(listener);
  });
}
