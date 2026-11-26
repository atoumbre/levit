part of '../../levit_flutter.dart';

/// A mixin that connects a [LevitController] to the Flutter application lifecycle.
///
/// Automatically registers a [WidgetsBindingObserver] during [onInit] and
/// detaches it on [requestCancel] and [onClose]. Subclasses overriding
/// [onInit], [requestCancel], or [onClose] must delegate to `super`.
///
/// ```dart
/// class SyncController extends LevitController with LevitAppLifecycleMixin {
///   @override
///   void onAppResumed() {
///     refreshFeed();
///   }
/// }
/// ```
///
/// {@category Flutter Widgets & Interop}
mixin LevitAppLifecycleMixin on LevitController {
  _AppLifecycleObserver? _observer;

  void _detachObserver() {
    final observer = _observer;
    if (observer != null) {
      WidgetsBinding.instance.removeObserver(observer);
      _observer = null;
    }
  }

  @override
  void onInit() {
    super.onInit();
    _detachObserver();
    final observer = _AppLifecycleObserver(this);
    _observer = observer;
    WidgetsBinding.instance.addObserver(observer);
  }

  @override
  void requestCancel() {
    _detachObserver();
    super.requestCancel();
  }

  @override
  FutureOr<void> onClose() {
    _detachObserver();
    return super.onClose();
  }

  /// Called when the application is visible and responding to user input
  /// ([AppLifecycleState.resumed]).
  void onAppResumed() {}

  /// Called when the application is not visible to the user and running in the
  /// background ([AppLifecycleState.paused]).
  void onAppPaused() {}

  /// Called when the application is inactive and not receiving user input
  /// ([AppLifecycleState.inactive]).
  void onAppInactive() {}

  /// Called when the Flutter engine is detached from any host views
  /// ([AppLifecycleState.detached]).
  void onAppDetached() {}

  /// Called when all views of the application are hidden
  /// ([AppLifecycleState.hidden]).
  void onAppHidden() {}
}

class _AppLifecycleObserver with WidgetsBindingObserver {
  final LevitAppLifecycleMixin _mixin;

  _AppLifecycleObserver(this._mixin);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_mixin.isClosing || _mixin.isDisposed) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _mixin.onAppResumed();
        break;
      case AppLifecycleState.paused:
        _mixin.onAppPaused();
        break;
      case AppLifecycleState.inactive:
        _mixin.onAppInactive();
        break;
      case AppLifecycleState.detached:
        _mixin.onAppDetached();
        break;
      case AppLifecycleState.hidden:
        _mixin.onAppHidden();
        break;
    }
  }
}
