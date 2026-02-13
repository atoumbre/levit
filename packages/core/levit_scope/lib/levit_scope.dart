/// Type-safe hierarchical dependency injection and lifecycle runtime for Dart.
///
/// This package provides Levit's DI container model:
/// * [LevitScope] for scoped registration, resolution, and deterministic teardown.
/// * [LevitScopeDisposable] for dependencies with explicit init/close callbacks.
/// * [LevitScopeMiddleware] for interception of DI lifecycle events.
///
/// `levit_scope` is reflection-free and relies on explicit types, tags, and
/// scope boundaries.
library;

import 'dart:async';

part 'src/core.dart';
part 'src/middleware.dart';
part 'src/global_accessor.dart';
part 'src/extensions.dart';
