/// Recommended single-import kit for Flutter applications using Levit.
///
/// Composes `levit_flutter_core`, `levit_dart`, and Flutter-specific kit
/// utilities into one import surface while hiding low-level `Ls` and `Lx`
/// facades in favor of [Levit] and `context.levit`.
///
/// ### Flutter kit additions
/// * [showLevitDialog] / [showLevitModalBottomSheet]: Imperative overlays that
///   capture the nearest widget scope via [LScope.capture].
/// * [LevitAppLifecycleMixin]: Bridges Flutter [AppLifecycleState] callbacks to
///   [LevitController].
/// * [LevitLoopLifecycleMixin]: Automatically pauses and resumes
///   [LevitLoopEngine] services with the app lifecycle.
///
/// ### Additional entry points
/// * `package:levit_flutter/tasks.dart`: Standalone `LevitTaskEngine`,
///   `LevitTaskGroup`, caching, middleware, tracking, and `LevitTaskResult`.
/// * `package:levit_flutter/levit_testing.dart`: Isolated `LevitTestScope` and
///   typed overrides for widget and unit tests.
///
/// ```dart
/// import 'package:flutter/widgets.dart';
/// import 'package:levit_flutter/levit_flutter.dart';
///
/// void main() {
///   Levit.enableAutoLinking();
///   runApp(
///     LScopedView<CounterController>.put(
///       () => CounterController(),
///       builder: (context, controller) => Text('${controller.count()}'),
///     ),
///   );
/// }
/// ```
///
/// @docImport 'package:levit_dart/levit_dart.dart';
/// @docImport 'package:levit_flutter_core/levit_flutter_core.dart';
/// @docImport 'src/overlays.dart';
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

export 'package:levit_dart/levit_dart.dart';
export 'package:levit_flutter_core/levit_flutter_core.dart' hide Ls, Lx;
export 'src/overlays.dart';

// Part files require these symbols at library scope for mixin constraints.
import 'package:levit_dart/levit_dart.dart'
    show LevitController, LevitLoopMixin;

part 'src/mixins/app_lifecycle_mixin.dart';
part 'src/mixins/lifecycle_loop_mixin.dart';
