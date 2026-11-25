part of '../../levit_dart.dart';

/// Controller-owned repeated work. Cancellation begins before resource cleanup.
mixin LevitLoopExecutionMixin on LevitController {
  late final LevitLoopEngine loopEngine = own(LevitLoopEngine());

  @override
  void requestCancel() {
    // Initialize/register before the owner closes admission.
    loopEngine.requestCancel();
    super.requestCancel();
  }
}
