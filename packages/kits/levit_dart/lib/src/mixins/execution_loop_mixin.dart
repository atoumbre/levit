part of '../../levit_dart.dart';

/// A mixin for [LevitController] that manages background loops and stoppable services.
///
/// This mixin provides controller-scoped execution management with automatic cleanup.
mixin LevitLoopExecutionMixin on LevitController {
  final LevitLoopEngine loopEngine = LevitLoopEngine();

  @override
  FutureOr<void> onClose() {
    loopEngine.dispose();
    return super.onClose();
  }
}
