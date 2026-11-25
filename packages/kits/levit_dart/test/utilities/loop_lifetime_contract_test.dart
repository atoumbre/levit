import 'dart:async';
import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class _LoopOwner extends LevitController with LevitLoopMixin {}

class _Service implements LevitLoopService {
  @override
  final status = LxVar<LxStatus<dynamic>>(LxIdle());
  int resumes = 0;
  @override
  void start() {}
  @override
  void pause() {}
  @override
  void resume() {
    resumes++;
  }

  @override
  Future<void> stop() => status.close();
}

void main() {
  test('loop body finally finishes before owner releases its state', () async {
    final owner = _LoopOwner();
    final state = owner.own(0.lx);
    final entered = Completer<void>();
    final gate = Completer<void>();
    final observed = <bool>[];
    owner.loopEngine.startLoop('loop', () async {
      entered.complete();
      try {
        await gate.future;
      } finally {
        observed.add(state.isDisposed);
      }
    });
    await entered.future;
    var disposed = false;
    final cleanup = Future<void>.sync(
      owner.onClose,
    ).then((_) => disposed = true);
    await Future<void>.value();
    expect(disposed, isFalse);
    expect(state.isDisposed, isFalse);
    gate.complete();
    await cleanup;
    expect(observed, [false]);
    expect(state.isDisposed, isTrue);
  });

  test('bulk resume preserves explicit manual pause', () async {
    final engine = LevitLoopEngine();
    final manual = engine.registerService('manual', _Service());
    final automatic = engine.registerService('automatic', _Service());
    engine.pauseService('manual');
    engine.pauseAllServices();
    engine.resumeAllServices();
    expect(manual.resumes, 0);
    expect(automatic.resumes, 1);
    engine.resumeService('manual');
    expect(manual.resumes, 1);
    await engine.dispose();
  });

  test(
    'replacement requires awaited stop and cannot overlap its old body',
    () async {
      final engine = LevitLoopEngine();
      final gate = Completer<void>();
      engine.startLoop('loop', () => gate.future);
      expect(() => engine.startLoop('loop', () async {}), throwsStateError);
      final stopped = engine.stopService('loop');
      expect(() => engine.startLoop('loop', () async {}), throwsStateError);
      gate.complete();
      await stopped;
      engine.startLoop('loop', () async {});
      await engine.dispose();
    },
  );

  test('a loop cannot await disposal of its owner', () async {
    final owner = _LoopOwner();
    final checked = Completer<void>();
    owner.loopEngine.startLoop('loop', () async {
      expect(owner.onClose, throwsStateError);
      checked.complete();
      owner.loopEngine.requestCancel();
    });
    await checked.future;
    await owner.onClose();
  });
}
