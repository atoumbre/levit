part of '../kit_library.dart';

/// Adds a controller-owned [LevitLoopEngine] for managed periodic or continuous
/// background workloads.
///
/// The [loopEngine] is lazily owned via [own] and cooperatively cancelled during
/// [requestCancel] before owned resources close. Subclasses overriding
/// [requestCancel] must delegate to `super.requestCancel()`.
///
/// In Flutter apps, pair with `LevitLoopLifecycleMixin` from `levit_flutter` to
/// pause and resume loops with the application lifecycle.
///
/// ```dart
/// class PollerController extends LevitController with LevitLoopMixin {
///   @override
///   void onInit() {
///     super.onInit();
///     loopEngine.startLoop(
///       'heartbeat',
///       () async => await api.ping(),
///       delay: const Duration(seconds: 15),
///     );
///   }
/// }
/// ```
///
/// {@category Loops, Timers & Selection}
mixin LevitLoopMixin on LevitController {
  /// The [LevitLoopEngine] owned by this controller.
  late final LevitLoopEngine loopEngine = own(LevitLoopEngine());

  @override
  void requestCancel() {
    // Initialize/register before the owner closes admission.
    loopEngine.requestCancel();
    super.requestCancel();
  }
}
