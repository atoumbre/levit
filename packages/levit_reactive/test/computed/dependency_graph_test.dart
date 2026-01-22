import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

/// Test middleware to capture dependency graph changes
class DepGraphCapture extends LevitReactiveMiddleware {
  LxReactive? lastTarget;
  List<LxReactive>? lastReactives;

  @override
  void Function(LxReactive, List<LxReactive>)? get onGraphChange =>
      (computed, dependencies) {
        lastTarget = computed;
        lastReactives = dependencies;
      };
}

void main() {
  group('LevitReactiveMiddleware.onGraphChange', () {
    test('LxComputed notifies onDependencyGraphChange', () {
      final source = 1.lx;
      final capture = DepGraphCapture();
      Lx.addMiddleware(capture);

      try {
        final computed = LxComputed(() => source.value * 2);

        // Activation triggers recompute which calls _reconcileDependencies
        computed.addListener(() {});

        expect(capture.lastTarget, same(computed));
        expect(capture.lastReactives, contains(source));
      } finally {
        Lx.removeMiddleware(capture);
      }
    });

    test('LxAsyncComputed notifies onDependencyGraphChange', () async {
      final source = 1.lx;
      final capture = DepGraphCapture();
      Lx.addMiddleware(capture);

      try {
        final computed = LxComputed.async(() async => source.value * 2);

        computed.addListener(() {});
        // Wait for async computation to complete and notify
        await Future.delayed(const Duration(milliseconds: 50));

        expect(capture.lastTarget, same(computed));
        expect(capture.lastReactives, contains(source));
      } finally {
        Lx.removeMiddleware(capture);
      }
    });
  });
}
