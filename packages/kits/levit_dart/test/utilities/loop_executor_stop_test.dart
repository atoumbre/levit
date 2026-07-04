import 'dart:async';
import 'dart:isolate';
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

  group('isolate command handler', () {
    test('handles pause command', () async {
      final lib = reflectClass(LevitLoopEngine).owner as LibraryMirror;
      final isPausedSymbol = MirrorSystem.getSymbol('_isPaused', lib);
      final executor = _newLoopExecutor(lib);
      final receivePort = ReceivePort();
      final subscription = receivePort.listen((_) {});

      _invokeIsolateCommandHandler(
        lib,
        'pause',
        executor.reflectee,
        subscription,
        receivePort,
        () {},
      );

      expect(executor.getField(isPausedSymbol).reflectee, isTrue);

      await subscription.cancel();
      receivePort.close();
    });

    test('handles resume command', () async {
      final lib = reflectClass(LevitLoopEngine).owner as LibraryMirror;
      final isPausedSymbol = MirrorSystem.getSymbol('_isPaused', lib);
      final executor = _newLoopExecutor(lib);
      final receivePort = ReceivePort();
      final subscription = receivePort.listen((_) {});

      executor.setField(isPausedSymbol, true);
      _invokeIsolateCommandHandler(
        lib,
        'resume',
        executor.reflectee,
        subscription,
        receivePort,
        () {},
      );

      expect(executor.getField(isPausedSymbol).reflectee, isFalse);

      await subscription.cancel();
      receivePort.close();
    });

    test('handles stop command', () async {
      final lib = reflectClass(LevitLoopEngine).owner as LibraryMirror;
      final isStoppedSymbol = MirrorSystem.getSymbol('_isStopped', lib);
      final executor = _newLoopExecutor(lib);
      final receivePort = ReceivePort();
      final subscription = receivePort.listen((_) {});
      var exited = false;

      _invokeIsolateCommandHandler(
        lib,
        'stop',
        executor.reflectee,
        subscription,
        receivePort,
        () => exited = true,
      );
      await Future<void>.delayed(Duration.zero);

      expect(executor.getField(isStoppedSymbol).reflectee, isTrue);
      expect(exited, isTrue);
    });
  });
}

InstanceMirror _newLoopExecutor(LibraryMirror lib) {
  final executorSymbol = MirrorSystem.getSymbol('_LoopExecutor', lib);
  final executorClass = lib.declarations[executorSymbol] as ClassMirror;
  final statuses = <LxStatus<dynamic>>[];

  return executorClass.newInstance(const Symbol(''), [
    () {},
    null,
    (LxStatus<dynamic> status) => statuses.add(status),
  ]);
}

void _invokeIsolateCommandHandler(
  LibraryMirror lib,
  dynamic message,
  Object executor,
  StreamSubscription<dynamic> subscription,
  ReceivePort receivePort,
  void Function() exit,
) {
  final serviceSymbol = MirrorSystem.getSymbol('_IsolateLoopService', lib);
  final handlerSymbol = MirrorSystem.getSymbol('_handleCommand', lib);
  final serviceClass = lib.declarations[serviceSymbol] as ClassMirror;
  serviceClass.invoke(handlerSymbol, [
    message,
    executor,
    subscription,
    receivePort,
    exit,
  ]);
}
