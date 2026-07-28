part of '../levit_reactive.dart';

/// Cache eviction policy for [LxFamily] entries.
sealed class LxFamilyEviction {
  const LxFamilyEviction._();

  /// Retains entries until explicit invalidation or family disposal.
  const factory LxFamilyEviction.keepAlive() = LxFamilyKeepAlive;

  /// Evicts entries after they remain without listeners for [gracePeriod].
  const factory LxFamilyEviction.whenInactive({
    Duration gracePeriod,
  }) = LxFamilyWhenInactive;
}

/// An eviction policy that retains every family entry.
final class LxFamilyKeepAlive extends LxFamilyEviction {
  /// Creates a keep-alive policy.
  const LxFamilyKeepAlive() : super._();
}

/// An eviction policy based on reactive listener activity.
final class LxFamilyWhenInactive extends LxFamilyEviction {
  /// Delay between becoming inactive and eviction.
  final Duration gracePeriod;

  /// Creates an inactivity eviction policy.
  const LxFamilyWhenInactive({
    this.gracePeriod = Duration.zero,
  }) : super._();
}

/// Lazily creates, caches, and disposes reactive resources by key.
///
/// Raw keys are never included in diagnostic names unless [debugKey] is
/// explicitly provided.
class LxFamily<K, R extends LxReactive<dynamic>> {
  /// Creates a keyed reactive family.
  LxFamily(
    this._builder, {
    this.eviction = const LxFamilyEviction.keepAlive(),
    this.name,
    this.debugKey,
  });

  final R Function(K key) _builder;

  /// Eviction policy applied to cached entries.
  final LxFamilyEviction eviction;

  /// Optional stable diagnostic prefix.
  final String? name;

  /// Optional application-controlled safe key formatter.
  final String Function(K key)? debugKey;

  final Map<K, _LxFamilyEntry<R>> _entries = <K, _LxFamilyEntry<R>>{};
  bool _isDisposed = false;

  /// Whether the family has been permanently closed.
  bool get isDisposed => _isDisposed;

  /// Number of currently cached keyed resources.
  int get length => _entries.length;

  /// Snapshot of cached keys.
  Iterable<K> get keys => List<K>.unmodifiable(_entries.keys);

  /// Whether [key] currently has a cached entry.
  bool containsKey(K key) => _entries.containsKey(key);

  /// Returns the existing entry for [key] or creates it lazily.
  R call(K key) {
    if (_isDisposed) {
      throw StateError('LxFamily${name == null ? '' : ' "$name"'} is closed.');
    }

    final existing = _entries[key];
    if (existing != null) {
      final reactive = existing.reactive;
      if (reactive is! LxBase || !reactive.isDisposed) {
        return reactive;
      }
      _removeEntry(key, existing, close: false);
    }

    final reactive = _builder(key);
    _assignDiagnosticName(key, reactive);
    final entry = _LxFamilyEntry<R>(reactive);
    _entries[key] = entry;
    _installEviction(key, entry);
    return reactive;
  }

  /// Invalidates and closes the entry associated with [key].
  bool invalidate(K key) {
    final entry = _entries[key];
    if (entry == null) return false;
    _removeEntry(key, entry, close: true);
    return true;
  }

  /// Invalidates and closes every cached entry.
  void invalidateAll() {
    for (final key in _entries.keys.toList(growable: false)) {
      invalidate(key);
    }
  }

  /// Permanently closes the family and all cached entries.
  void close() {
    if (_isDisposed) return;
    _isDisposed = true;
    invalidateAll();
  }

  void _assignDiagnosticName(K key, R reactive) {
    if (name == null || reactive.name != null) return;

    String safeKey;
    try {
      safeKey =
          debugKey?.call(key) ?? key.hashCode.toUnsigned(32).toRadixString(16);
    } catch (_) {
      safeKey = 'key';
    }
    reactive.name = '$name[$safeKey]';
  }

  void _installEviction(K key, _LxFamilyEntry<R> entry) {
    final policy = eviction;
    if (policy is! LxFamilyWhenInactive) return;

    final reactive = entry.reactive;
    if (reactive is LxBase) {
      void activityObserver(bool active) {
        if (active) {
          entry.evictionTimer?.cancel();
          entry.evictionTimer = null;
        } else {
          _scheduleEviction(key, entry, policy.gracePeriod);
        }
      }

      entry.activityObserver = activityObserver;
      reactive._addActivityObserver(activityObserver);
      if (!reactive.hasListener) {
        _scheduleEviction(key, entry, policy.gracePeriod);
      }
      return;
    }

    // Custom LxReactive implementations have no activity hook. They remain
    // deterministic by being evicted after the configured grace period.
    _scheduleEviction(key, entry, policy.gracePeriod);
  }

  void _scheduleEviction(
    K key,
    _LxFamilyEntry<R> entry,
    Duration gracePeriod,
  ) {
    entry.evictionTimer?.cancel();
    entry.evictionTimer = Timer(gracePeriod, () {
      if (!identical(_entries[key], entry)) return;
      final reactive = entry.reactive;
      if (reactive is LxBase && reactive.hasListener) return;
      _removeEntry(key, entry, close: true);
    });
  }

  void _removeEntry(
    K key,
    _LxFamilyEntry<R> entry, {
    required bool close,
  }) {
    if (!identical(_entries[key], entry)) return;
    _entries.remove(key);
    entry.evictionTimer?.cancel();
    final observer = entry.activityObserver;
    final reactive = entry.reactive;
    if (observer != null && reactive is LxBase) {
      reactive._removeActivityObserver(observer);
    }
    if (close) {
      reactive.close();
    }
  }
}

final class _LxFamilyEntry<R extends LxReactive<dynamic>> {
  _LxFamilyEntry(this.reactive);

  final R reactive;
  Timer? evictionTimer;
  void Function(bool active)? activityObserver;
}
