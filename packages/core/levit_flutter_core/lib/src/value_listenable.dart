part of '../levit_flutter_core.dart';

/// A Flutter [ValueListenable] that borrows an [LxReadable] source.
///
/// Reads always use the source's current value. The adapter subscribes only while
/// it has listeners and forwards every source notification, including refreshes
/// of mutable collections. It does not compare values or take ownership of them.
///
/// Create this once at a controller or widget lifetime boundary, rather than in
/// every build. [dispose] unsubscribes without closing the source. The source's
/// owner must keep it alive for as long as consumers need it.
///
/// Implements [LevitDisposable], so a controller can `own(source.asValueListenable())`.
/// Expose it as [ValueListenable] to consumers that only need observation.
///
/// {@category Flutter Widgets & Interop}
final class LevitValueListenable<T>
    implements ValueListenable<T>, LevitDisposable {
  LxReadable<T>? _source;
  final _notifier = _ValueListenableNotifier();
  final _listeners = <VoidCallback, List<VoidCallback>>{};
  bool _subscribed = false;
  int _notificationDepth = 0;

  /// Creates a borrowing adapter. Construction does not subscribe to [source].
  LevitValueListenable(LxReadable<T> source) : _source = source;

  /// Whether this adapter has released its subscription.
  bool get isDisposed => _source == null;

  LxReadable<T> get _activeSource =>
      _source ?? (throw StateError('ValueListenable adapter is disposed.'));

  /// The current source value. Throws [StateError] after adapter disposal.
  @override
  T get value => _activeSource.value;

  /// Subscribes to source notifications. Duplicate callbacks are registered
  /// separately, following Flutter's [ChangeNotifier] convention.
  ///
  /// Throws a [StateError] if called after [dispose].
  @override
  void addListener(VoidCallback listener) {
    final source = _activeSource;
    void forward() {
      if (!isDisposed) listener();
    }

    (_listeners[listener] ??= []).add(forward);
    _notifier.addListener(forward);
    if (!_subscribed) {
      _subscribed = true;
      try {
        source.addListener(_notify);
      } catch (_) {
        removeListener(listener);
        rethrow;
      }
    }
  }

  /// Removes one registration. Safe after disposal, including widget teardown.
  @override
  void removeListener(VoidCallback listener) {
    final registrations = _listeners[listener];
    if (registrations == null) return;
    _notifier.removeListener(registrations.removeAt(0));
    if (registrations.isEmpty) _listeners.remove(listener);
    if (_listeners.isEmpty && _subscribed) {
      _subscribed = false;
      _source?.removeListener(_notify);
    }
  }

  void _notify() {
    if (isDisposed) return;
    _notificationDepth++;
    try {
      _notifier.publish();
    } finally {
      _notificationDepth--;
      if (isDisposed && _notificationDepth == 0) _notifier.dispose();
    }
  }

  /// Idempotently stops notifications and releases only this subscription.
  ///
  /// Disposal during a callback suppresses the remaining callbacks. The borrowed
  /// source is never mutated or closed; reads/new subscriptions then throw.
  @override
  void dispose() {
    final source = _source;
    if (source == null) return;
    _source = null;
    _listeners.clear();
    try {
      if (_subscribed) source.removeListener(_notify);
    } finally {
      _subscribed = false;
      if (_notificationDepth == 0) _notifier.dispose();
    }
  }
}

final class _ValueListenableNotifier extends ChangeNotifier {
  void publish() => notifyListeners();
}

/// Borrowing interoperability with Flutter APIs that accept [ValueListenable].
///
/// {@category Flutter Widgets & Interop}
extension LxReadableValueListenable<T> on LxReadable<T> {
  /// Creates an independently disposable [LevitValueListenable] adapter.
  ///
  /// Retain and own it outside `build` (for example via `own(...)` in a
  /// controller) and dispose it at its owning boundary.
  ///
  /// ```dart
  /// class CounterController extends LevitController {
  ///   final count = 0.lx;
  ///   late final ValueListenable<int> countListenable =
  ///       own(count.asValueListenable());
  /// }
  /// ```
  LevitValueListenable<T> asValueListenable() => LevitValueListenable<T>(this);
}
