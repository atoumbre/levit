/// Advanced task orchestration APIs for pure Dart Levit applications.
///
/// Re-exports `package:levit_dart/tasks.dart` ([LevitTaskEngine],
/// [LevitTaskGroup], [LevitTaskResult], [LevitTaskMiddleware],
/// [LevitTaskTracker], caching, and isolate tasks).
///
/// ```dart
/// import 'package:levit/levit.dart';
/// import 'package:levit/tasks.dart';
///
/// final engine = LevitTaskEngine(maxConcurrent: 4);
/// final result = await engine.schedule((ctx) => computeSummary());
/// await engine.dispose();
/// ```
///
/// @docImport 'package:levit_dart/tasks.dart';
library;

export 'package:levit_dart/tasks.dart';
