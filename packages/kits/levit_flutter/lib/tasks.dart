/// Advanced task orchestration APIs for Flutter applications using Levit.
///
/// Re-exports `package:levit_dart/tasks.dart` ([LevitTaskEngine],
/// [LevitTaskGroup], [LevitTaskResult], [LevitTaskMiddleware],
/// [LevitTaskTracker], caching, and isolate tasks).
///
/// ```dart
/// import 'package:levit_flutter/levit_flutter.dart';
/// import 'package:levit_flutter/tasks.dart';
///
/// class AppController extends LevitController {
///   late final tracker = own(LevitTaskTracker()..attach(token: #tasks));
/// }
/// ```
///
/// @docImport 'package:levit_dart/tasks.dart';
library;

export 'package:levit_dart/tasks.dart';
