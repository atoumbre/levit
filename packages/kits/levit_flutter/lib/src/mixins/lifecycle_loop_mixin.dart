part of '../../levit_flutter.dart';

/// A mixin that synchronizes execution loops with the app lifecycle.
///
/// Automatically pauses all tasks in the [loopEngine] when the app enters the
/// background, and resumes them when the app returns to the foreground.
///
/// Requires [LevitLoopExecutionMixin].
mixin LevitLoopExecutionLifecycleMixin
    on LevitController, LevitLoopExecutionMixin {
  _LifecycleLoopObserver? _lifecycleObserver;

  void _detachLifecycleObserver() {
    final observer = _lifecycleObserver;
    if (observer != null) {
      WidgetsBinding.instance.removeObserver(observer);
      _lifecycleObserver = null;
    }
  }

  @override
  void onInit() {
    super.onInit();
    _detachLifecycleObserver();
    final observer = _LifecycleLoopObserver(this);
    _lifecycleObserver = observer;
    WidgetsBinding.instance.addObserver(observer);
  }

  @override
  void requestCancel() {
    _detachLifecycleObserver();
    super.requestCancel();
  }

  @override
  FutureOr<void> onClose() {
    _detachLifecycleObserver();
    return super.onClose();
  }

  /// Whether to pause services marked as "permanent" during the app backgrounding.
  ///
  /// Defaults to `false` (permanent services continue running).
  bool get pauseLifecycleServicesForce => false;
}

class _LifecycleLoopObserver with WidgetsBindingObserver {
  final LevitLoopExecutionLifecycleMixin _mixin;

  _LifecycleLoopObserver(this._mixin);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_mixin.isClosing || _mixin.isDisposed) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _mixin.loopEngine.resumeAllServices(
          force: _mixin.pauseLifecycleServicesForce,
        );
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _mixin.loopEngine.pauseAllServices(
          force: _mixin.pauseLifecycleServicesForce,
        );
        break;
    }
  }
}
