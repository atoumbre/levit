/// Isolated scopes and typed overrides for pure Dart Levit tests.
///
/// Re-exports `package:levit/levit.dart` alongside [LevitTestScope] and
/// [LevitTestException].
///
/// ```dart
/// final testScope = LevitTestScope(overrides: [
///   counterStore.overrideWith((ref) => ref.own(10.lx)),
/// ]);
/// addTearDown(testScope.close);
/// ```
///
/// @docImport 'package:levit_dart/levit_testing.dart';
library;

export 'package:levit_dart/levit_testing.dart';
export 'levit.dart';
