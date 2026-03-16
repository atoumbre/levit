import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

class DepGraphCapture extends LevitReactiveMiddleware {
  LxReactive? capturedComputed;
  List<LxReactive>? capturedDeps;
  @override void Function(LxReactive, List<LxReactive>)? get onGraphChange => (computed, dependencies) {
    capturedComputed = computed; capturedDeps = dependencies;
  };
}

void main() {
  test('Sync Computed triggers onDependencyGraphChange via middleware', () {
    final capture = DepGraphCapture();
    Lx.addMiddleware(capture);
    addTearDown(() => Lx.removeMiddleware(capture));

    final count = 0.lx;
    final doubleCount = (() => count.value * 2).lx;

    expect(doubleCount.value, 0);
    count.value++;
    expect(doubleCount.value, 2);
    expect(capture.capturedComputed, equals(doubleCount));
    expect(capture.capturedDeps, contains(count));
  });
}
