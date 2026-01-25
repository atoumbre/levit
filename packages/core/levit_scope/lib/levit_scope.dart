/// Type-safe, hierarchical dependency injection for Dart.
///
/// This package provides the core dependency injection mechanism of the Levit framework:
/// *   [LevitScope]: A scoped container for managing dependency lifecycles.
/// *   [LevitScopeDisposable]: An interface for objects that require explicit initialization or disposal.
///
/// `levit_scope` focuses on deterministic resource management and explicit scoping
/// without reliance on code generation or reflection.
library;

import 'dart:async';

part 'src/core.dart';
part 'src/middleware.dart';
part 'src/global_accessor.dart';
part 'src/extensions.dart';
