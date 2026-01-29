part of '../../levit_flutter.dart';

/// A mixin that automatically pauses execution loops when the app goes to background.
///
/// It requires [LevitExecutionLoopMixin] to function.
mixin LevitLifecycleLoopMixin
    on LevitController, LevitExecutionLoopMixin
    implements WidgetsBindingObserver {
  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        pauseAllServices(force: pauseLifecycleServicesForce);
        break;
      case AppLifecycleState.resumed:
        resumeAllServices(force: pauseLifecycleServicesForce);
        break;
      default:
        // Do nothing for inactive or detached
        break;
    }
  }

  /// Override this to return true if you want to force pause even permanent tasks
  /// when the app goes to background.
  ///
  /// Defaults to `false`.
  bool get pauseLifecycleServicesForce => false;
}
