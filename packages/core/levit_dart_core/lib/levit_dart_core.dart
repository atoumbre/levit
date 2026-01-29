/// Core Levit framework for Dart.
///
/// This package provides the foundational building blocks for Levit applications:
/// *   [LevitController]: Base class for business logic components.
/// *   [LevitState]: Functional state and dependency provider.
/// *   Re-exports of `levit_scope` and `levit_reactive`.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:developer' as dev;
import 'package:levit_scope/levit_scope.dart';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:meta/meta.dart';

export 'package:levit_scope/levit_scope.dart';
export 'package:levit_reactive/levit_reactive.dart';

part 'src/controller.dart';
part 'src/core.dart';
part 'src/auto_linking.dart';
part 'src/state.dart';
