/// Low-level Flutter bindings for the Levit runtime.
///
/// This package maps Levit scope and reactive semantics to Flutter widget
/// lifecycle boundaries and rebuild mechanics.
///
/// ### Core widgets
/// * [LScope]: Provides widget-tree-scoped dependency injection with
///     deterministic cleanup.
/// * [LView]: A specialized widget family for reactive views.
/// * [LScopedView]: A specialized widget family for reactive views with
///     widget-tree-scoped dependency injection.
/// * [LWatch]: The primary building block for reactive UIs. It automatically
///     tracks reactive dependencies accessed during build.
/// * [LBuilder]: A specialized widget family for reactive status management.
library;

export 'package:levit_dart_core/levit_dart_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:levit_dart_core/levit_dart_core.dart';

part 'src/scope.dart';
part 'src/view.dart';
part 'src/watch.dart';
part 'src/builder.dart';
part 'src/scoped_view.dart';
