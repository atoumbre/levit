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
  test('Pull-on-read Sync Computed triggers onDependencyGraphChange', () {
    final capture = DepGraphCapture();
    Lx.addMiddleware(capture);
    addTearDown(() => Lx.removeMiddleware(capture));

    final count = 10.lx;
    final computed = (() => count.value * 5).lx;
    final val = computed.value;

    expect(val, 50);
    expect(capture.capturedComputed, equals(computed));
    expect(capture.capturedDeps, contains(count));
  });
}
