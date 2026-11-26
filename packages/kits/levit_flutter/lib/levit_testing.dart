/// Isolated scopes and typed overrides for Flutter Levit tests.
///
/// Re-exports `package:levit_flutter/levit_flutter.dart` alongside
/// [LevitTestScope] and [LevitTestException].
///
/// ```dart
/// final testScope = LevitTestScope(overrides: [
///   counterStore.overrideWith((ref) => ref.own(1.lx)),
/// ]);
/// addTearDown(testScope.close);
/// ```
///
/// @docImport 'package:levit_dart/levit_testing.dart';
library;

export 'package:levit_dart/levit_testing.dart';
export 'levit_flutter.dart';
