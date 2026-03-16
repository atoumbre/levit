import 'dart:async';
import 'dart:mirrors';

import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

void main() {
  test('stopping a paused loop executor completes the pause completer',
      () async {
    final lib = reflectClass(LevitLoopEngine).owner as LibraryMirror;
    final executorSymbol = MirrorSystem.getSymbol('_LoopExecutor', lib);
    final isPausedSymbol = MirrorSystem.getSymbol('_isPaused', lib);
    final pauseCompleterSymbol = MirrorSystem.getSymbol('_pauseCompleter', lib);
    final executorClass = lib.declarations[executorSymbol] as ClassMirror;
    final statuses = <LxStatus<dynamic>>[];

    final executor = executorClass.newInstance(const Symbol(''), [
      () {},
      null,
      (LxStatus<dynamic> status) => statuses.add(status),
    ]);

    executor.setField(isPausedSymbol, true);
    executor.invoke(#start, const []);
    await Future<void>.delayed(Duration.zero);

    final pauseCompleter =
        executor.getField(pauseCompleterSymbol).reflectee as Completer<void>?;
    expect(pauseCompleter, isNotNull);
    expect(pauseCompleter!.isCompleted, isFalse);

    executor.invoke(#stop, const []);
    await Future<void>.delayed(Duration.zero);

    expect(pauseCompleter.isCompleted, isTrue);
    expect(statuses.last, isA<LxIdle<dynamic>>());
  });
}
