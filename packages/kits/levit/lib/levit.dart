/// Recommended single-import kit for pure Dart Levit applications.
///
/// Re-exports `package:levit_dart/levit_dart.dart` (covering scopes,
/// controllers, stores, reactive primitives, tasks, async maps, timers,
/// selection, and loops) while hiding low-level `Ls` and `Lx` facades in favor
/// of the unified [Levit] entry point.
///
/// Use this package for CLI tools, servers, and shared domain packages that do
/// not depend on Flutter.
///
/// ### Additional entry points
/// * `package:levit/tasks.dart`: Standalone `LevitTaskEngine`, `LevitTaskGroup`,
///   isolate tasks, caching, middleware, tracking, and `LevitTaskResult`.
/// * `package:levit/levit_testing.dart`: Isolated `LevitTestScope` and typed
///   store overrides.
///
/// ```dart
/// import 'package:levit/levit.dart';
///
/// Future<void> main() async {
///   Levit.enableAutoLinking();
///   final greeting = await Levit.runInScope(() {
///     final name = Levit.put(() => 'Levit'.lx);
///     return 'Hello, ${name()}!';
///   });
/// }
/// ```
///
/// @docImport 'package:levit_dart/levit_dart.dart';
library;

export 'package:levit_dart/levit_dart.dart';
