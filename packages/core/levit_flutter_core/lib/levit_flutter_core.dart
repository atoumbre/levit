/// Flutter bindings for the Levit runtime.
///
/// This package maps Levit scope and reactive semantics to Flutter widget
/// lifecycle boundaries and rebuild mechanics.
///
/// It owns the Flutter binding layer and re-exports
/// `package:levit_dart_core/levit_dart_core.dart` for convenience. The
/// Dart-side composition APIs still belong to `levit_dart_core`.
///
/// ### Core widgets & bindings
/// * [LScope] / [LAsyncScope]: Create widget-owned scopes with deterministic
///   cleanup (coordinated via [LevitScopeLifecycleController]).
/// * [LScope.capture]: Re-provide the nearest scope to dialogs and overlays
///   that are no longer descendants of the original subtree.
/// * [LRouteScope] / [LAsyncRouteScope]: Bind a scope to the current
///   [ModalRoute] and expose [LRouteVisibility] as reactive state.
/// * [LView] / [LAsyncView]: Consume dependencies from an existing scope.
/// * [LScopedView] / [LAsyncScopedView]: Create a child scope and resolve a
///   dependency in one widget.
/// * [LevitContext] (`context.levit`): Resolve or register dependencies from
///   the nearest widget scope.
/// * [LWatch]: The primary proxy-tracked reactive rebuild boundary.
/// * [LBuilder]: Explicitly rebuild from a single [LxReadable].
/// * [LSelectorBuilder]: Build from a local derived value for a small subtree.
/// * [LStatusBuilder]: Render waiting, error, and success states for
///   [LxStatus].
/// * [LxValueListenable] (`asValueListenable()`): Borrowing [ValueListenable]
///   adapter for Flutter APIs.
library;

import 'dart:async';
import 'package:flutter/foundation.dart' show ValueListenable;

export 'package:levit_dart_core/levit_dart_core.dart';
import 'package:flutter/widgets.dart';
import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_dart_core/spi.dart';

part 'src/scope.dart';
part 'src/scope_lifecycle.dart';
part 'src/l_scope.dart';
part 'src/l_async_scope.dart';
part 'src/levit_provider.dart';
part 'src/route_scope.dart';
part 'src/view.dart';
part 'src/watch.dart';
part 'src/builder.dart';
part 'src/scoped_view.dart';
part 'src/value_listenable.dart';
