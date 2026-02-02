part of '../../levit_flutter.dart';

/// A mixin that synchronizes execution loops with the app lifecycle.
///
/// Automatically pauses all tasks in the [loopEngine] when the app enters the
/// background, and resumes them when the app returns to the foreground.
///
/// Requires [LevitLoopExecutionMixin].
mixin LevitLoopExecutionLifecycleMixin
    on LevitController, LevitLoopExecutionMixin {
  late final _LifecycleLoopObserver _lifecycleObserver;

  @override
  void onInit() {
    super.onInit();
    _lifecycleObserver = _LifecycleLoopObserver(this);
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    super.onClose();
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
    switch (state) {
      case AppLifecycleState.paused:
        _mixin.loopEngine
            .pauseAllServices(force: _mixin.pauseLifecycleServicesForce);
        break;
      case AppLifecycleState.resumed:
        _mixin.loopEngine
            .resumeAllServices(force: _mixin.pauseLifecycleServicesForce);
        break;
      default:
        // Do nothing for inactive or detached
        break;
    }
  }
}
