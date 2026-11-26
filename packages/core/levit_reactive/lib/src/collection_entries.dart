part of 'reactive_library.dart';

enum _ReadKind { element, membership, length, empty, keys }

typedef _Element = ({bool exists, Object? value});

bool get _capturingCollection =>
    _LevitReactiveCore.proxy != null ||
    (_LevitReactiveCore._asyncTrackerDepth > 0 &&
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
    if (_controller == null &&
        !LevitReactiveMiddleware._hasDisposeMiddlewares) {
      dispose();
    } else {
      collection._retire(this);
    }
  }

  void publish(Object? snapshot) {
    _value = snapshot;
    final recordBatch =
        LevitReactiveMiddleware._hasBatchMiddlewares &&
        _LevitReactiveCore.isBatching;
    if (_controller == null &&
        !LevitReactiveMiddleware._hasSetMiddlewares &&
        !recordBatch) {
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
  Map<Object?, _EntryChannel>? _elementChannels;
  Map<Object?, _EntryChannel>? _membershipChannels;
  _EntryChannel? _lengthChannel;
  _EntryChannel? _emptyChannel;
  _EntryChannel? _keysChannel;
  _EntryChannel? _soleChannel;
  int _channelCount = 0;
  // Immutable across a notification. Subscription changes invalidate the cache.
  List<_EntryChannel>? _channelSnapshot;
  List<_EntryChannel>? _pendingRetireChecks;
  Set<Future<void>>? _retirements;
  List<AsyncError>? _retirementErrors;

  bool get _hasChannels => _channelCount > 0;

  // Keep physical addresses distinct across backing-map replacements. The
  // equality index accelerates a single write to an ordinary Dart map.
  Map<Object?, List<_EntryChannel>>? _equalElementAddresses;
  Map<Object?, List<_EntryChannel>>? _equalMembershipAddresses;

  /// Number of live observation channels, for diagnostics and leak tests.
  int get observedChannelCount => _channelCount;

  bool _forceRefresh = false;
  bool Function(Object?)? _written;
  Object? _oneAddress;
  bool _singleWrite = false;
  (int, int)? _listRange;
  bool get _standardAddresses;
  _Element _element(Object? address);
  bool _existsAt(Object? address);
  Object? _valueAt(Object? address);
  int get _count;

  Object? _sample(_ReadKind kind, Object? address) => switch (kind) {
    _ReadKind.element => _element(address),
    _ReadKind.membership => _existsAt(address),
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
    return switch (kind) {
      _ReadKind.element => _elementChannels?[address],
      _ReadKind.membership => _membershipChannels?[address],
      _ReadKind.length => _lengthChannel,
      _ReadKind.empty => _emptyChannel,
      _ReadKind.keys => _keysChannel,
    };
  }

  _EntryChannel _channel(_ReadKind kind, Object? address) =>
      _lookup(kind, address) ?? _createChannel(kind, address);

  _EntryChannel _createChannel(_ReadKind kind, Object? address) {
    if (isDisposed) throw StateError('Collection is closed.');
    final channel =
        LevitReactiveMiddleware._hasInitMiddlewares
            ? LxSpi.createOwned(() => _EntryChannel(this, kind, address))
            : _EntryChannel(this, kind, address);
    channel.ownerId = ownerId;
    if (!_hasChannels) {
      _soleChannel = channel;
    } else {
      if (_soleChannel case final sole?) {
        _soleChannel = null;
        _index(sole);
      }
      _index(channel);
    }
    _channelCount++;
    // Captures reconcile after the read. A discarded capture needs no
    // permanent slot, even if it read a missing address.
    _scheduleRetireCheck(channel);
    return channel;
  }

  void _scheduleRetireCheck(_EntryChannel channel) {
    final pending = _pendingRetireChecks;
    if (pending != null) {
      pending.add(channel);
      return;
    }
    _pendingRetireChecks = <_EntryChannel>[channel];
    scheduleMicrotask(_flushRetireChecks);
  }

  void _flushRetireChecks() {
    final pending = _pendingRetireChecks;
    _pendingRetireChecks = null;
    if (pending == null) return;
    for (var i = 0; i < pending.length; i++) {
      pending[i].retireIfUnused();
    }
  }

  void _index(_EntryChannel c) {
    _channelSnapshot = null;
    switch (c.kind) {
      case _ReadKind.element:
        (_elementChannels ??= Map.identity())[c.address] = c;
        if (this is LxMap && _standardAddresses) {
          ((_equalElementAddresses ??= {})[c.address] ??= []).add(c);
        }
      case _ReadKind.membership:
        (_membershipChannels ??= Map.identity())[c.address] = c;
        if (this is LxMap && _standardAddresses) {
          ((_equalMembershipAddresses ??= {})[c.address] ??= []).add(c);
        }
      case _ReadKind.length:
        _lengthChannel = c;
      case _ReadKind.empty:
        _emptyChannel = c;
      case _ReadKind.keys:
        _keysChannel = c;
    }
  }

  void _removeEqualAddress(
    Map<Object?, List<_EntryChannel>>? buckets,
    _EntryChannel c,
  ) {
    if (buckets == null) return;
    final bucket = buckets[c.address];
    if (bucket != null) {
      bucket.remove(c);
      if (bucket.isEmpty) buckets.remove(c.address);
    }
  }

  void _removeChannel(_EntryChannel c) {
    _channelSnapshot = null;
    if (identical(_soleChannel, c)) {
      _soleChannel = null;
      _channelCount--;
      return;
    }
    var removed = false;
    switch (c.kind) {
      case _ReadKind.element:
        final map = _elementChannels;
        if (map != null && identical(map[c.address], c)) {
          map.remove(c.address);
          removed = true;
          if (map.isEmpty) _elementChannels = null;
          _removeEqualAddress(_equalElementAddresses, c);
        }
      case _ReadKind.membership:
        final map = _membershipChannels;
        if (map != null && identical(map[c.address], c)) {
          map.remove(c.address);
          removed = true;
          if (map.isEmpty) _membershipChannels = null;
          _removeEqualAddress(_equalMembershipAddresses, c);
        }
      case _ReadKind.length:
        if (identical(_lengthChannel, c)) {
          _lengthChannel = null;
          removed = true;
        }
      case _ReadKind.empty:
        if (identical(_emptyChannel, c)) {
          _emptyChannel = null;
          removed = true;
        }
      case _ReadKind.keys:
        if (identical(_keysChannel, c)) {
          _keysChannel = null;
          removed = true;
        }
    }
    if (removed) _channelCount--;
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
    final prevSingle = _singleWrite;
    final prevAddress = _oneAddress;
    final prevWritten = _written;
    final prevRange = _listRange;
    _singleWrite = single;
    _oneAddress = address;
    _written = written;
    _listRange = listRange;
    try {
      super.refresh();
    } finally {
      _singleWrite = prevSingle;
      _oneAddress = prevAddress;
      _written = prevWritten;
      _listRange = prevRange;
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

  void _publishChannel(
    _EntryChannel channel, {
    required bool single,
    required Object? address,
    required bool Function(Object?)? written,
    required bool force,
    required (int, int)? range,
  }) {
    final kind = channel.kind;
    final key = channel.address;
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
    final same =
        kind == _ReadKind.keys
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

  List<_EntryChannel> _buildChannelSnapshot() {
    final list = <_EntryChannel>[];
    if (_elementChannels case final map?) list.addAll(map.values);
    if (_membershipChannels case final map?) list.addAll(map.values);
    if (_lengthChannel case final ch?) list.add(ch);
    if (_emptyChannel case final ch?) list.add(ch);
    if (_keysChannel case final ch?) list.add(ch);
    return list;
  }

  void _publishAllChannels({
    required _EntryChannel? sole,
    required bool single,
    required Object? address,
    required bool Function(Object?)? written,
    required bool force,
    required (int, int)? range,
  }) {
    if (sole != null) {
      _publishChannel(
        sole,
        single: single,
        address: address,
        written: written,
        force: force,
        range: range,
      );
    } else if (!single || !_standardAddresses) {
      final snapshot = _channelSnapshot ??= _buildChannelSnapshot();
      for (var i = 0; i < snapshot.length; i++) {
        _publishChannel(
          snapshot[i],
          single: single,
          address: address,
          written: written,
          force: force,
          range: range,
        );
      }
    } else {
      if (this is LxMap) {
        final elMatches = _equalElementAddresses?[address];
        if (elMatches != null) {
          for (var i = 0; i < elMatches.length; i++) {
            _publishChannel(
              elMatches[i],
              single: single,
              address: address,
              written: written,
              force: force,
              range: range,
            );
          }
        }
        final memMatches = _equalMembershipAddresses?[address];
        if (memMatches != null) {
          for (var i = 0; i < memMatches.length; i++) {
            _publishChannel(
              memMatches[i],
              single: single,
              address: address,
              written: written,
              force: force,
              range: range,
            );
          }
        }
      } else {
        final elTarget = _elementChannels?[address];
        if (elTarget != null) {
          _publishChannel(
            elTarget,
            single: single,
            address: address,
            written: written,
            force: force,
            range: range,
          );
        }
        final memTarget = _membershipChannels?[address];
        if (memTarget != null) {
          _publishChannel(
            memTarget,
            single: single,
            address: address,
            written: written,
            force: force,
            range: range,
          );
        }
      }
      if (_lengthChannel case final ch?) {
        _publishChannel(
          ch,
          single: single,
          address: address,
          written: written,
          force: force,
          range: range,
        );
      }
      if (_emptyChannel case final ch?) {
        _publishChannel(
          ch,
          single: single,
          address: address,
          written: written,
          force: force,
          range: range,
        );
      }
      if (_keysChannel case final ch?) {
        _publishChannel(
          ch,
          single: single,
          address: address,
          written: written,
          force: force,
          range: range,
        );
      }
    }
    super._publishMutation();
  }

  @override
  void _publishMutation() {
    if (!_hasChannels) {
      super._publishMutation();
      return;
    }
    final sole = _soleChannel;
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
      if (!LevitReactiveMiddleware._hasBatchMiddlewares) {
        _LevitReactiveCore._batchDepth++;
        _LevitReactiveCore._updateFastNotify();
        try {
          _publishAllChannels(
            sole: sole,
            single: single,
            address: address,
            written: written,
            force: force,
            range: range,
          );
        } finally {
          _LevitReactiveCore._batchDepth--;
          _LevitReactiveCore._updateFastNotify();
          if (_LevitReactiveCore._batchDepth == 0) {
            _LevitReactiveCore._flushGlobalBatch();
          }
        }
      } else {
        Lx.batch(() {
          _publishAllChannels(
            sole: sole,
            single: single,
            address: address,
            written: written,
            force: force,
            range: range,
          );
        });
      }
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
    final sole = _soleChannel;
    final elements = _elementChannels;
    final memberships = _membershipChannels;
    final lengthCh = _lengthChannel;
    final emptyCh = _emptyChannel;
    final keysCh = _keysChannel;
    _soleChannel = null;
    _elementChannels = null;
    _membershipChannels = null;
    _lengthChannel = null;
    _emptyChannel = null;
    _keysChannel = null;
    _channelCount = 0;
    _channelSnapshot = null;
    _pendingRetireChecks = null;
    _equalElementAddresses = null;
    _equalMembershipAddresses = null;
    final bindingCleanup = super._cleanupBinding();
    final pending = <Future<void>>[
      if (bindingCleanup is Future<void>) bindingCleanup,
      if (sole != null) sole.close(),
      if (elements != null)
        for (final channel in elements.values) channel.close(),
      if (memberships != null)
        for (final channel in memberships.values) channel.close(),
      if (lengthCh != null) lengthCh.close(),
      if (emptyCh != null) emptyCh.close(),
      if (keysCh != null) keysCh.close(),
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

  /// Whether the underlying collection has been closed.
  bool get isClosed => _source.isDisposed;

  /// Whether this key or index currently exists in the underlying collection.
  ///
  /// Tracks membership changes without notifying on in-place value updates,
  /// distinguishing an absent entry from an entry storing `null`.
  bool get exists {
    _source._observe(_ReadKind.membership, _address);
    return _source._existsAt(_address);
  }

  /// The current value at this entry's key or index, or `null` when absent.
  ///
  /// Tracks only this specific address in the collection. Throws a [StateError]
  /// if [isClosed] is `true`.
  @override
  V? get value {
    if (isClosed) throw StateError('Collection is closed.');
    _source._observe(_ReadKind.element, _address);
    return _source._valueAt(_address) as V?;
  }

  @override
  void addListener(void Function() listener) =>
      _source._channel(_ReadKind.element, _address).addListener(listener);
  @override
  void removeListener(void Function() listener) =>
      _source._lookup(_ReadKind.element, _address)?.removeListener(listener);

  /// A broadcast [Stream] emitting values for this entry as it changes.
  ///
  /// Closes immediately if [isClosed] is already `true`.
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

/// Borrowing reactive observation of a single [LxMap] key, including removal
/// and reinsertion.
///
/// Entries borrow their backing [LxMap] and do not need to be closed.
///
/// ```dart
/// final scores = <String, int>{'alice': 10}.lx;
/// final alice = scores.entry('alice');
/// final label = LxComputed(() => alice.exists ? '${alice.value}' : 'missing');
/// ```
///
/// {@category Reactive State}
final class LxMapEntry<V> extends _BorrowedEntry<V> {
  LxMapEntry._(super.source, super.address);
}

/// Borrowing reactive observation of a single [LxList] index, including
/// temporary absence when the list shrinks and grows again.
///
/// Entries borrow their backing [LxList] and do not need to be closed.
///
/// ```dart
/// final items = <String>['first'].lx;
/// final head = items.entry(0);
/// final title = LxComputed(() => head.exists ? head.value! : 'empty');
/// ```
///
/// {@category Reactive State}
final class LxListEntry<T> extends _BorrowedEntry<T> {
  LxListEntry._(super.source, super.address);
}
