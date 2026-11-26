part of '../../levit_flutter.dart';

/// A mixin that synchronizes [LevitLoopEngine] services with the Flutter
/// application lifecycle.
///
/// Automatically calls [LevitLoopEngine.pauseAllServices] when the app enters
/// [AppLifecycleState.paused], [AppLifecycleState.inactive],
/// [AppLifecycleState.hidden], or [AppLifecycleState.detached], and calls
/// [LevitLoopEngine.resumeAllServices] when the app returns to
/// [AppLifecycleState.resumed].
///
/// Services marked `permanent: true` remain running unless
/// [pausePermanentServicesOnBackground] is overridden to `true`. Services
/// individually paused via [LevitLoopEngine.pauseService] are not resumed
/// automatically. Subclasses overriding [onInit], [requestCancel], or
/// [onClose] must delegate to `super`.
///
/// Requires [LevitLoopMixin].
///
/// ```dart
/// class TelemetryController extends LevitController
///     with LevitLoopMixin, LevitLoopLifecycleMixin {
///   @override
///   void onInit() {
///     super.onInit();
///     loopEngine.startLoop(
///       'metrics',
///       () async => await flushMetrics(),
///       delay: const Duration(seconds: 30),
///     );
///   }
/// }
/// ```
///
/// {@category Flutter Widgets & Interop}
mixin LevitLoopLifecycleMixin on LevitController, LevitLoopMixin {
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

  /// Whether to also pause and resume services marked `permanent: true` when
  /// the app leaves and returns to the foreground.
  ///
  /// Passed as `force` to both [LevitLoopEngine.pauseAllServices] and
  /// [LevitLoopEngine.resumeAllServices]. Defaults to `false` (permanent
  /// services continue running).
  bool get pausePermanentServicesOnBackground => false;
}

class _LifecycleLoopObserver with WidgetsBindingObserver {
  final LevitLoopLifecycleMixin _mixin;

  _LifecycleLoopObserver(this._mixin);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_mixin.isClosing || _mixin.isDisposed) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _mixin.loopEngine.resumeAllServices(
          force: _mixin.pausePermanentServicesOnBackground,
        );
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _mixin.loopEngine.pauseAllServices(
          force: _mixin.pausePermanentServicesOnBackground,
        );
        break;
    }
  }
}
