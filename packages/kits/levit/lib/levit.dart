/// Recommended single-import kit for pure Dart Levit applications.
///
/// This library re-exports `package:levit_dart/levit_dart.dart`, which includes
/// Levit's Dart composition layer (`levit_dart_core`) and foundational runtime
/// packages (`levit_scope` and `levit_reactive`) through transitive exports.
///
/// Use this package for CLI, server, and shared-domain code that does not need
/// Flutter widget bindings.
library levit;

export 'package:levit_dart/levit_dart.dart';
