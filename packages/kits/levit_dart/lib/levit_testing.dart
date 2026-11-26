/// Isolated test scopes and typed store overrides for `levit_dart`.
///
/// Re-exports `package:levit_dart/levit_dart.dart` alongside
/// [LevitTestScope] and [LevitTestException] (hiding low-level `Ls` and `Lx`).
///
/// ```dart
/// final testScope = LevitTestScope(overrides: [
///   counterStore.overrideWith((ref) => ref.own(0.lx)),
/// ]);
/// addTearDown(testScope.close);
/// ```
///
/// @docImport 'package:levit_dart_core/levit_testing.dart';
library;

export 'package:levit_dart_core/levit_testing.dart' hide Ls, Lx;
export 'levit_dart.dart';
