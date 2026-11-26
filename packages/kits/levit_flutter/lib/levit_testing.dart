/// Isolated scopes and typed overrides for Flutter Levit tests.
///
/// Re-exports `package:levit_flutter/levit_flutter.dart` alongside
/// [LevitTestScope] and [LevitTestException]. Constructing [LevitTestScope]
/// automatically calls [LevitFlutter.ensureInitialized], so controllers owning
/// Flutter [ChangeNotifier] resources dispose cleanly even in non-widget tests.
///
/// ```dart
/// final testScope = LevitTestScope(overrides: [
///   counterStore.overrideWith((ref) => ref.own(1.lx)),
/// ]);
/// addTearDown(testScope.close);
/// ```
///
/// @docImport 'package:flutter/foundation.dart';
/// @docImport 'package:levit_dart/levit_testing.dart';
library;

import 'package:levit_dart/levit_testing.dart' as dart_testing;
import 'levit_flutter.dart';

export 'package:levit_dart/levit_testing.dart' hide LevitTestScope;
export 'levit_flutter.dart';

/// Isolated Flutter test scope that ensures Flutter resource adapters and
/// default auto-linking are initialized before creating the root scope.
///
/// {@category Testing}
final class LevitTestScope extends dart_testing.LevitTestScope {
  /// Creates an isolated root scope named [name] and applies [overrides].
  factory LevitTestScope({
    String name = 'test',
    Iterable<LevitOverride> overrides = const [],
  }) {
    LevitFlutter.ensureInitialized();
    return LevitTestScope._(name: name, overrides: overrides);
  }

  LevitTestScope._({super.name, super.overrides});
}
