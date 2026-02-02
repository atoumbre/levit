part of '../../levit_flutter.dart';

/// A mixin that connects a [LevitController] to the Flutter application lifecycle.
///
/// Automatically registers a [WidgetsBindingObserver] when the controller is
/// initialized and removes it when closed.
///
/// Example:
/// ```dart
/// class MyController extends LevitController with LevitAppLifecycleMixin {
///   @override
///   void onAppResumed() {
///     print('App is back!');
///     fetchData();
///   }
/// }
/// ```
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

  /// Called when the application is not visible to the user and running in the background.
  void onAppPaused() {}

  /// Called when the application is in an inactive state and not receiving input.
  void onAppInactive() {}

  /// Called when the flutter engine is detached from any host views.
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
