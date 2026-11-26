part of '../levit_flutter_core.dart';

/// Flutter runtime integration hooks for Levit.
///
/// Widget entry points such as [LScope], [LAsyncScope], [LView], [LAsyncView],
/// and [LScopedView] call [ensureInitialized] automatically. Call
/// [ensureInitialized] directly in non-widget Flutter tests when you
/// instantiate a [LevitController] that owns a [ChangeNotifier] outside
/// `LevitTestScope` or a widget tree.
///
/// {@category Flutter Widgets & Interop}
abstract final class LevitFlutter {
  static final Object _changeNotifierAdapterToken = Object();

  /// Ensures Flutter-specific Levit integrations are registered.
  ///
  /// Safe to call repeatedly:
  /// - Enables default Flutter auto-linking unless the application explicitly
  ///   opted out via [Levit.disableAutoLinking].
  /// - Registers a [ChangeNotifier] disposal adapter so [LevitController.own]
  ///   and [LevitRef.own] dispose `TextEditingController`, `FocusNode`,
  ///   `ScrollController`, `AnimationController`, `ValueNotifier`, and custom
  ///   [ChangeNotifier] subclasses without an explicit `dispose:` callback.
  static void ensureInitialized() {
    LevitAutoLinkSpi.ensureFlutterDefaultAutoLinking();
    if (!LevitResourceDisposerSpi.hasAdapter(_changeNotifierAdapterToken)) {
      LevitResourceDisposerSpi.registerAdapter(
        token: _changeNotifierAdapterToken,
        matches: (resource) => resource is ChangeNotifier,
        dispose: (resource) => (resource as ChangeNotifier).dispose(),
      );
    }
  }
}
