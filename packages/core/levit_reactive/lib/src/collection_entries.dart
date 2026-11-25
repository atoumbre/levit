part of '../levit_reactive.dart';

enum _ReadKind { element, membership, length, empty, keys }

typedef _Element = ({bool exists, Object? value});

bool get _capturingCollection =>
    _LevitReactiveCore.proxy != null ||
    (_LevitReactiveCore._asyncZoneDepth > 0 &&
        Zone.current[_LevitReactiveCore.asyncComputedTrackerZoneKey]
            is LevitReactiveObserver);

// The channel owns no producer or binding. Only streams and diagnostics need
// asynchronous disposal. Both still use the regular reactive close path.
final class _EntryChannel extends LxBase<Object?> {
  _EntryChannel(this.collection, this.kind, this.address)
    : super(collection._sample(kind, address), isSensitive: true);
  final _PreciseCollection collection;
  final _ReadKind kind;
  final Object? address;

  @override
  String get name =>
      _name ??= '${collection.name ?? collection.runtimeType}[$id]';

  @override
  void _protectedOnInactive() => retireIfUnused();

  void retireIfUnused() {
    if (isDisposed || hasListener) return;
    collection._removeChannel(this);
    if (_controller == null && !LevitReactiveMiddleware.hasDisposeMiddlewares) {
      dispose();
    } else {
      collection._retire(this);
    }
  }

  void publish(Object? snapshot) {
    _value = snapshot;
    if (_controller == null && !LevitReactiveMiddleware.hasSetMiddlewares) {
      _notifyListenersOnly();
    } else {
      super.refresh();
    }
  }
}

class _CollectionIterable<E> extends Iterable<E> {
  final Iterable<E> Function() read;
  _CollectionIterable(this.read);
  @override
  Iterator<E> get iterator => read().iterator;
}

mixin _PreciseCollection<C, V> on LxVar<C> {
  Map<_ReadKind, Map<Object?, _EntryChannel>>? _channels;
  _EntryChannel? _soleChannel;
  // Immutable across a notification. Subscription changes invalidate the cache.
  List<_EntryChannel>? _channelSnapshot;
  Set<Future<void>>? _retirements;
  List<AsyncError>? _retirementErrors;

  bool get _hasChannels => _soleChannel != null || _channels != null;

  // Keep physical addresses distinct across backing-map replacements. The
  // equality index accelerates a single write to an ordinary Dart map.
  late final _equalAddresses = <_ReadKind, Map<Object?, List<_EntryChannel>>>{};

  /// Number of live observation channels, for diagnostics and leak tests.
  int get observedChannelCount => _soleChannel != null
      ? 1
      : (_channels?.values.fold<int>(0, (n, group) => n + group.length) ?? 0);

  bool _forceRefresh = false;
  bool Function(Object?)? _written;
  Object? _oneAddress;
  bool _singleWrite = false;
  (int, int)? _listRange;
  bool get _standardAddresses;
  _Element _element(Object? address);
  int get _count;

  Object? _sample(_ReadKind kind, Object? address) => switch (kind) {
    _ReadKind.element => _element(address),
    _ReadKind.membership => _element(address).exists,
    _ReadKind.length => _count,
    _ReadKind.empty => _count == 0,
    _ReadKind.keys => (this as LxMap)._orderedKeys.toList(growable: false),
  };

  _EntryChannel? _lookup(_ReadKind kind, Object? address) {
    final sole = _soleChannel;
    if (sole != null) {
      return sole.kind == kind && identical(sole.address, address)
          ? sole
          : null;
    }
    return _channels?[kind]?[address];
  }

  _EntryChannel _channel(_ReadKind kind, Object? address) =>
      _lookup(kind, address) ?? _createChannel(kind, address);

  _EntryChannel _createChannel(_ReadKind kind, Object? address) {
    if (isDisposed) throw StateError('Collection is closed.');
    final channel = LevitReactiveMiddleware.hasInitMiddlewares
        ? Lx.createOwned(() => _EntryChannel(this, kind, address))
        : _EntryChannel(this, kind, address);
    channel.ownerId = ownerId;
    if (!_hasChannels) {
      _soleChannel = channel;
    } else {
      if (_soleChannel case final sole?) {
        _channels = {};
        _index(sole);
        _soleChannel = null;
      }
      _index(channel);
    }
    // Captures reconcile after the read. A discarded capture needs no
    // permanent slot, even if it read a missing address.
    scheduleMicrotask(channel.retireIfUnused);
    return channel;
  }

  bool _needsEqualityIndex(_EntryChannel c) =>
      this is LxMap &&
      _standardAddresses &&
      (c.kind == _ReadKind.element || c.kind == _ReadKind.membership);

  void _index(_EntryChannel c) {
    _channelSnapshot = null;
    (_channels![c.kind] ??= Map.identity())[c.address] = c;
    if (_needsEqualityIndex(c)) {
      ((_equalAddresses[c.kind] ??= {})[c.address] ??= []).add(c);
    }
  }

  void _removeChannel(_EntryChannel c) {
    _channelSnapshot = null;
    if (identical(_soleChannel, c)) {
      _soleChannel = null;
      return;
    }
    final slots = _channels?[c.kind];
    if (slots == null) return;
    slots.remove(c.address);
    final buckets = this is LxMap ? _equalAddresses[c.kind] : null;
    if (buckets != null) {
      final bucket = buckets[c.address];
      bucket?.remove(c);
      if (bucket != null && bucket.isEmpty) buckets.remove(c.address);
    }
    if (slots.isEmpty) _channels!.remove(c.kind);
    if (_channels!.isEmpty) _channels = null;
  }

  void _retire(_EntryChannel channel) {
    final pending = _retirements ??= {};
    final completion = Completer<void>();
    // A disposal hook can close the parent synchronously. Reserve before it runs.
    pending.add(completion.future);
    Future<void> finish() async {
      try {
        await channel.close();
      } catch (error, stack) {
        (_retirementErrors ??= []).add(AsyncError(error, stack));
      } finally {
        pending.remove(completion.future);
        completion.complete();
      }
    }

    unawaited(finish());
  }

  @pragma('vm:prefer-inline')
  void _observe(_ReadKind kind, [Object? address]) {
    final tracker = _LevitReactiveCore.proxy;
    if (tracker is _DependencyTracker) {
      tracker.hasCollectionReads = true;
      final expected = tracker._expected;
      if (expected != null && tracker._matched < expected.length) {
        final next = expected[tracker._matched];
        if (next is _EntryChannel &&
            identical(next.collection, this) &&
            next.kind == kind &&
            identical(next.address, address) &&
            !next.isDisposed) {
          tracker._matched++;
          _LevitReactiveCore._lastReportedObserver = tracker;
          _LevitReactiveCore._lastReportedReactive = next;
          if (tracker.trackReactives) tracker.addReactive(next);
          return;
        }
      }
    } else if (tracker == null && !_capturingCollection) {
      return;
    }
    _channel(kind, address).value;
  }

  void _changed({
    Object? address,
    bool single = false,
    bool Function(Object?)? written,
    (int, int)? listRange,
  }) {
    if (!_hasChannels) {
      super.refresh();
      return;
    }
    final previous = (_singleWrite, _oneAddress, _written, _listRange);
    _singleWrite = single;
    _oneAddress = address;
    _written = written;
    _listRange = listRange;
    try {
      super.refresh();
    } finally {
      _singleWrite = previous.$1;
      _oneAddress = previous.$2;
      _written = previous.$3;
      _listRange = previous.$4;
    }
  }

  @override
  void refresh() {
    final previous = _forceRefresh;
    _forceRefresh = true;
    try {
      super.refresh();
    } finally {
      _forceRefresh = previous;
    }
  }

  @override
  void _publishMutation() {
    final channels = _channels;
    final sole = _soleChannel;
    if (channels == null && sole == null) {
      super._publishMutation();
      return;
    }
    final single = _singleWrite;
    final address = _oneAddress;
    final written = _written;
    final force = _forceRefresh;
    final range = _listRange;
    _listRange = null;
    // Nested listener writes must start with their own mutation description.
    _singleWrite = false;
    _written = null;
    _forceRefresh = false;
    try {
      Lx.batch(() {
        void publish(_ReadKind kind, Object? key, _EntryChannel channel) {
          if (range != null &&
              !force &&
              (kind == _ReadKind.element || kind == _ReadKind.membership)) {
            final index = key as int;
            if (index < range.$1 || index >= range.$2) return;
            if (kind == _ReadKind.element) {
              channel.publish(_element(index));
              return;
            }
          }
          if (single &&
              kind == _ReadKind.keys &&
              !force &&
              (channel._value as List).length == _count) {
            return;
          }
          final next = _sample(kind, key);
          final previous = channel._value;
          final same = kind == _ReadKind.keys
              ? _sameOrder(previous as List, next as List)
              : kind == _ReadKind.element
              ? (previous as _Element).exists == (next as _Element).exists &&
                    identical(previous.value, next.value)
              : previous == next;
          if (!same ||
              force ||
              (kind == _ReadKind.element &&
                  (single &&
                          (_standardAddresses
                              ? address == key
                              : identical(address, key)) ||
                      (written?.call(key) ?? false)))) {
            channel.publish(next);
          }
        }

        if (sole != null) {
          publish(sole.kind, sole.address, sole);
        } else if (!single || !_standardAddresses) {
          final snapshot = _channelSnapshot ??= [
            for (final group in channels!.values) ...group.values,
          ];
          for (final channel in snapshot) {
            publish(channel.kind, channel.address, channel);
          }
        } else {
          for (final group in channels!.entries.toList()) {
            final kind = group.key;
            if (kind == _ReadKind.element || kind == _ReadKind.membership) {
              if (this is LxMap) {
                final matches = _equalAddresses[kind]?[address];
                if (matches != null) {
                  for (final target in matches) {
                    publish(kind, address, target);
                  }
                }
              } else {
                final target = group.value[address];
                if (target != null) publish(kind, address, target);
              }
            } else {
              for (final item in group.value.entries.toList()) {
                publish(kind, item.key, item.value);
              }
            }
          }
        }
        super._publishMutation();
      });
    } finally {
      _singleWrite = single;
      _written = written;
      _forceRefresh = force;
      _listRange = range;
    }
  }

  bool _sameOrder(List a, List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (_standardAddresses ? a[i] != b[i] : !identical(a[i], b[i])) {
        return false;
      }
    }
    return true;
  }

  @override
  void mutate(void Function(C) mutator) {
    try {
      mutator(_value);
    } finally {
      _changed();
    }
  }

  @override
  void updateValue(C Function(C) update) {
    final C next;
    try {
      next = update(_value);
    } catch (_) {
      _changed();
      rethrow;
    }
    if (identical(next, _value)) {
      _changed();
    } else {
      _setValueInternal(next);
    }
  }

  @override
  Future<void> _cleanupBinding() async {
    final slots = _channels;
    final sole = _soleChannel;
    _soleChannel = null;
    _channels = null;
    _channelSnapshot = null;
    if (slots != null) _equalAddresses.clear();
    final pending = [
      super._cleanupBinding(),
      if (sole != null) sole.close(),
      if (slots != null)
        for (final group in slots.values)
          for (final channel in group.values) channel.close(),
    ];
    await Future.wait([
      ...?_retirements,
      for (final operation in pending)
        operation.catchError((Object error, StackTrace stack) {
          (_retirementErrors ??= []).add(AsyncError(error, stack));
        }),
    ]);
    if (_retirementErrors case final errors?) throw LxCleanupException(errors);
  }
}

abstract base class _BorrowedEntry<V> implements LxReadable<V?> {
  final _PreciseCollection<dynamic, V> _source;
  final Object? _address;
  _BorrowedEntry(this._source, this._address);

  @override
  final int id = LxBase._nextId++;
  bool get isClosed => _source.isDisposed;
  bool get exists {
    _source._observe(_ReadKind.membership, _address);
    return _source._element(_address).exists;
  }

  @override
  V? get value {
    if (isClosed) throw StateError('Collection is closed.');
    _source._observe(_ReadKind.element, _address);
    return _source._element(_address).value as V?;
  }

  @override
  void addListener(void Function() listener) =>
      _source._channel(_ReadKind.element, _address).addListener(listener);
  @override
  void removeListener(void Function() listener) =>
      _source._lookup(_ReadKind.element, _address)?.removeListener(listener);

  @override
  Stream<V?> get stream => Stream.multi((output) {
    if (isClosed) {
      output.closeSync();
      return;
    }
    final subscription = _source
        ._channel(_ReadKind.element, _address)
        .stream
        .listen(
          (frame) => output.addSync((frame as _Element).value as V?),
          onDone: output.closeSync,
        );
    output.onCancel = subscription.cancel;
  }, isBroadcast: true);
}

/// Borrowing observation of a map key, including removal and reinsertion.
final class LxMapEntry<V> extends _BorrowedEntry<V> {
  LxMapEntry._(super.source, super.address);
}

/// Borrowing observation of a list position, including temporary absence.
final class LxListEntry<T> extends _BorrowedEntry<T> {
  LxListEntry._(super.source, super.address);
}
