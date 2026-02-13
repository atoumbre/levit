/// Core Dart composition layer for the Levit ecosystem.
///
/// This library defines lifecycle-aware application building blocks and unifies
/// dependency injection and reactive state access:
///
/// * [Levit]: unified facade for scope, reactive batching, and middleware APIs.
/// * [LevitController]: lifecycle-aware owner for business logic and resources.
/// * [LevitStore] and [LevitAsyncStore]: scoped, reusable state definitions.
///
/// The library re-exports `levit_scope` and `levit_reactive` as foundational
/// runtime dependencies.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:developer' as dev;

import 'package:levit_reactive/levit_reactive.dart';
import 'package:levit_scope/levit_scope.dart';
import 'package:meta/meta.dart';

export 'package:levit_reactive/levit_reactive.dart';
export 'package:levit_scope/levit_scope.dart';

part 'src/auto_linking.dart';
part 'src/controller.dart';
part 'src/core.dart';
part 'src/store.dart';
