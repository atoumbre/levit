/// Core Dart composition layer for the Levit ecosystem.
///
/// Unifies dependency injection (`levit_scope`) and reactive state
/// (`levit_reactive`) into lifecycle-aware application building blocks:
///
/// * [Levit]: Unified facade for scoped DI, reactive batching, untracked reads,
///   auto-linking, and middleware APIs.
/// * [LevitController]: Lifecycle-aware owner for business logic and owned
///   resources (`own`, `onInit`, `onBeforeClose`, `onClose`).
/// * [LevitStore], [LevitAsyncStore], [LevitRef], [LevitOverride], and
///   [LevitScopeStoreOverrides]: Portable, per-scope state recipes and typed
///   overrides.
/// * [LxNamingExtension]: Fluent `.named()`, `.ownedBy()`, and `.sensitive()`
///   diagnostics helpers.
///
/// Isolated test helpers live in `package:levit_dart_core/levit_testing.dart`;
/// cross-package SPI hooks live in `package:levit_dart_core/spi.dart`.
///
/// @docImport 'src/dart_core_library.dart';
library;

export 'package:levit_reactive/levit_reactive.dart';
export 'package:levit_scope/levit_scope.dart';
export 'src/dart_core_library.dart'
    hide LevitAutoLinkSpi, LevitResourceDisposerSpi;
