import 'dart:async';
import 'package:levit_dart_core/levit_dart_core.dart';

/// Test controller for unit tests.
class TestController extends LevitController {
  bool closeCalled = false;
  int count = 0;
  final reactiveCount = 0.lx;

  @override
  void onClose() {
    closeCalled = true;
    super.onClose();
  }
}

/// Tracking subscription for disposal tests.
class TrackingSubscription<T> implements StreamSubscription<T> {
  final StreamSubscription<T> _inner;
  final void Function()? _onCancel;
  bool cancelCalled = false;

  TrackingSubscription(this._inner, [this._onCancel]);

  @override
  Future<void> cancel() {
    cancelCalled = true;
    _onCancel?.call();
    return _inner.cancel();
  }

  @override
  void onData(void Function(T data)? handleData) => _inner.onData(handleData);

  @override
  void onError(Function? handleError) => _inner.onError(handleError);

  @override
  void onDone(void Function()? handleDone) => _inner.onDone(handleDone);

  @override
  void pause([Future<void>? resumeSignal]) => _inner.pause(resumeSignal);

  @override
  void resume() => _inner.resume();

  @override
  bool get isPaused => _inner.isPaused;

  @override
  Future<E> asFuture<E>([E? futureValue]) => _inner.asFuture(futureValue);
}
