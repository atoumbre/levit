part of '../../levit_flutter.dart';

/// A mixin that exposes [WidgetsBindingObserver] lifecycle methods to a [LevitController].
///
/// Override [onAppResumed], [onAppPaused], [onAppInactive], [onAppDetached], or [onAppHidden]
/// to handle lifecycle changes.
mixin LevitAppLifecycleMixin on LevitController {
  late final _AppLifecycleObserver _observer;

  @override
  void onInit() {
    super.onInit();
    _observer = _AppLifecycleObserver(this);
    WidgetsBinding.instance.addObserver(_observer);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(_observer);
    super.onClose();
  }

  /// Called when the application is visible and responding to user input.
  void onAppResumed() {}

  /// Called when the application is not currently visible to the user, not responding to
  /// user input, and running in the background.
  void onAppPaused() {}

  /// Called when the application is in an inactive state and is not receiving user input.
  void onAppInactive() {}

  /// Called when the application is still hosted on a flutter engine but is detached from any host views.
  void onAppDetached() {}

  /// Called when the application is hidden.
  void onAppHidden() {}
}

class _AppLifecycleObserver with WidgetsBindingObserver {
  final LevitAppLifecycleMixin _mixin;

  _AppLifecycleObserver(this._mixin);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
