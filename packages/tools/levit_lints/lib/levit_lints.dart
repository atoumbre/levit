/// Native Dart analyzer rules for Levit lifecycle, reactive-state, and Flutter
/// widget scoping usage.
///
/// This package exposes [LevitLintsPlugin] as a native Dart analyzer plugin
/// (auto-discovered via `lib/main.dart`) with no Levit runtime dependency.
///
/// ## Configuration
///
/// Enable rules in your root `analysis_options.yaml`:
///
/// ```yaml
/// plugins:
///   levit_lints:
///     version: ^0.1.0
///     diagnostics:
///       await_levit_lifecycle: true
///       avoid_global_levit_in_widgets: true
///       discarded_levit_future: true
///       must_call_super_levit_lifecycle: true
///       unowned_levit_resource: true
///       avoid_plain_lx_status_fields: true
///       avoid_preconstructed_levit_put: true
///       avoid_redundant_outer_lwatch: true
///       avoid_unscoped_overlay: true
/// ```
///
/// ## Rules
///
/// - [AwaitLevitLifecycle] (`await_levit_lifecycle`): Require `await` or direct
///   `return` on async `super.onInit`, `super.onBeforeClose`, and `super.onClose`.
/// - [AvoidGlobalLevitInWidgets] (`avoid_global_levit_in_widgets`): Prefer
///   `context.levit.find*` over global `Levit.find*` inside Flutter widgets and
///   states.
/// - [DiscardedLevitFuture] (`discarded_levit_future`): Observe futures
///   returned by known Levit disposal, scope, task, loop, and reactive cleanup
///   APIs.
/// - [MustCallSuperLevitLifecycle] (`must_call_super_levit_lifecycle`): Require
///   `LevitController` lifecycle overrides to delegate to `super`.
/// - [UnownedLevitResource] (`unowned_levit_resource`): Detect discarded
///   `StreamSubscription`/`Timer` handles and unowned `late` reactive fields.
/// - [AvoidPlainLxStatusFields] (`avoid_plain_lx_status_fields`): Flag mutable
///   plain `LxStatus` fields and retained `.status` snapshots on owners.
/// - [AvoidPreconstructedLevitPut] (`avoid_preconstructed_levit_put`): Prevent
///   `Levit.put(() => existingOwner)` registrations that bypass builder-scoped
///   auto-linking.
/// - [AvoidRedundantOuterLWatch] (`avoid_redundant_outer_lwatch`): Avoid
///   returning a root `LWatch` inside `LView` / `LScopedView` / `LAsyncView`
///   when `autoWatch` is enabled.
/// - [AvoidUnscopedOverlay] (`avoid_unscoped_overlay`): Prefer
///   `showLevitDialog` / `showLevitModalBottomSheet` or `LScope.capture` over
///   raw Flutter overlays inside Levit Flutter widgets.
///
/// Suppress an intentional exception with a namespaced ignore comment, e.g.:
/// `// ignore: levit_lints/avoid_global_levit_in_widgets`.
///
/// @docImport 'main.dart';
/// @docImport 'src/rules.dart';
library;

export 'main.dart' show LevitLintsPlugin;
export 'src/rules.dart';
