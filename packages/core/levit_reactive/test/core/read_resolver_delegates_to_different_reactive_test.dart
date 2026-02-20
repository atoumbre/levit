import 'package:test/test.dart';
import 'dart:async';
import 'package:levit_reactive/levit_reactive.dart';
// Note: test should not import src/core.dart if possible, but Lx provides what we need

class _ResolverObserver
    implements LevitReactiveObserver, LevitReactiveReadResolver {
  final LxReactive original;
  final LxReactive replacement;
  LxReactive? observed;

  _ResolverObserver(this.original, this.replacement);

  @override
  void addNotifier(LevitReactiveNotifier notifier) {}

  @override
  void addReactive(LxReactive reactive) {
    observed = reactive;
  }

  @override
  LxReactive resolveReactiveRead(LxReactive reactive) {
    if (identical(reactive, original)) return replacement;
    return reactive;
  }
}

void main() {
  test('LevitReactiveReadResolver via proxy delegates read', () {
    final original = 1.lx;
    final replacement = 2.lx;
    final observer = _ResolverObserver(original, replacement);

    Lx.proxy = observer;
    // Reading original should hit proxy and defer to replacement.value
    final val = original.value;
    Lx.proxy = null;

    expect(val, 2);
    // When graphing is enabled (which it typically is not explicitly here without middleware),
    // addReactive would be called, but the main thing is it didn't throw and returned 2.
  });

  test('LevitReactiveReadResolver via zoneTracker delegates read', () {
    final original = 10.lx;
    final replacement = 20.lx;
    final observer = _ResolverObserver(original, replacement);

    int? resolvedVal;

    // Simulate _asyncZoneDepth > 0
    Lx.enterAsyncScope();
    runZoned(
      () {
        resolvedVal = original.value; // Hits lines 640-645 in core.dart
      },
      zoneValues: {
        Lx.asyncComputedTrackerZoneKey: observer,
      },
    );
    Lx.exitAsyncScope();

    expect(resolvedVal, 20);
  });
}
