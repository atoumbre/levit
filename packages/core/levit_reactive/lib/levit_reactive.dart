/// Pure Dart reactive state management primitives.
///
/// This package provides the low-level reactive engine of the Levit framework.
/// It is dependency-free and focuses on high-performance, fine-grained state
/// tracking using a proxy-based mechanism.
///
/// ### Core Abstractions
/// *   [LxReactive]: The base interface for all reactive objects.
/// *   [Lx]: The primary entry point for creating reactive variables and managing
///     the global reactive state (proxies, batches, middlewares).
/// *   [LxComputed]: Derived reactive state that automatically tracks dependencies.
///
/// `levit_reactive` is designed to be the foundational layer for any Dart
/// application requiring deterministic state derivation.
library;

import 'dart:async';
import 'dart:math';

import 'package:meta/meta.dart';

part 'src/async_status.dart';
part 'src/async_types.dart';
part 'src/base_types.dart';
part 'src/collections.dart';
part 'src/computed.dart';
part 'src/core.dart';
part 'src/global_accessor.dart';
part 'src/middlewares.dart';
part 'src/workers.dart';
