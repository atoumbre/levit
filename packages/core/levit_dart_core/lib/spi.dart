/// Service Provider Interface (SPI) for cross-package integrations with `levit_dart_core`.
///
/// Re-exports `levit_reactive/spi.dart` and `levit_scope/spi.dart` alongside
/// core resource ownership and auto-linking hooks without cluttering the
/// application-facing barrel.
library;

export 'package:levit_reactive/spi.dart';
export 'package:levit_scope/spi.dart';
export 'src/dart_core_library.dart'
    show LevitAutoLinkSpi, LevitResourceOwner, LevitResourceOwnership;
