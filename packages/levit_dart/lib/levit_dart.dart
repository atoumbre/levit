/// Core Levit framework for Dart.
///
/// This package provides the foundational building blocks for Levit applications:
/// *   [LevitController]: The base class for business logic components.

/// *   Re-exports of [levit_di] for dependency injection.
/// *   Re-exports of [levit_reactive] for reactive primitives.

library;

import 'dart:async';
import 'dart:collection';

import 'package:levit_di/levit_di.dart';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:meta/meta.dart';

export 'package:levit_di/levit_di.dart';
export 'package:levit_reactive/levit_reactive.dart';

part 'src/controller.dart';
part 'src/core.dart';
part 'src/middleware.dart';
part 'src/extensions.dart';
part 'src/scope.dart';
