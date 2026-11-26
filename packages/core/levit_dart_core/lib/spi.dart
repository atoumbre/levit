/// Service Provider Interface (SPI) for cross-package integrations with `levit_dart_core`.
///
/// Re-exports `package:levit_reactive/spi.dart` and
/// `package:levit_scope/spi.dart` alongside [LevitAutoLinkSpi] and
/// [LevitResourceDisposerSpi] without cluttering the application-facing barrel.
///
/// @docImport 'src/dart_core_library.dart';
library;

export 'package:levit_reactive/spi.dart';
export 'package:levit_scope/spi.dart';
export 'src/dart_core_library.dart'
    show LevitAutoLinkSpi, LevitResourceDisposerSpi;
