/// Flutter integration layer for the Levit framework.
///
/// This package provides the binding between Levit's core composition and
/// reactive layers and Flutter's widget tree.
///
/// ### Core Widgets
/// *   [LWatch]: The primary building block for reactive UIs. It automatically
///     tracks reactive dependencies accessed during build.
/// *   [LScope]: Provides widget-tree-scoped dependency injection with
///     deterministic cleanup.
/// *   [LWatchStatus]: A specialized widget for reactive status management.
///
/// `levit_flutter` enables scaling Flutter applications by providing explicit
/// rebuild boundaries and predictable resource lifecycles.
library;

export 'package:levit_dart_core/levit_dart_core.dart';
import 'package:flutter/widgets.dart';
import 'package:levit_dart_core/levit_dart_core.dart';

part 'src/scope.dart';
part 'src/view.dart';
part 'src/watch.dart';
