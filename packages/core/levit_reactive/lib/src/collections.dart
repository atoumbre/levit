part of 'reactive_library.dart';

/// A reactive list that notifies observers on modification.
///
/// [LxList] implements [List] and intercepts all mutating operations
/// (`add`, `remove`, `sort`, etc.) to trigger reactive updates.
///
/// ```dart
/// final items = <String>[].lx;
///
/// // Adding an item triggers observers
/// items.add('active');
/// ```
///
/// {@category Reactive State}
class LxList<E> extends LxVar<List<E>>
    with _PreciseCollection<List<E>, E>
    implements List<E> {
  /// Creates a reactive list.
  ///
  /// Backed by [initial] if provided, otherwise an empty list.
  LxList({List<E>? initial, String? name, bool isSensitive = false})
    : super(initial ?? <E>[], name: name, isSensitive: isSensitive);

  /// Creates an [LxList] containing all [elements].
  factory LxList.from(
    Iterable<E> elements, {
    String? name,
    bool isSensitive = false,
  }) {
    return LxList<E>(
      initial: List<E>.from(elements),
      name: name,
      isSensitive: isSensitive,
    );
  }

  @override
  bool get _standardAddresses => true;
  @override
  int get _count => _value.length;
  @override
  bool _existsAt(Object? index) => index is int && index >= 0 && index < _count;
  @override
  Object? _valueAt(Object? index) =>
      index is int && index >= 0 && index < _count ? _value[index] : null;
  @override
  _Element _element(Object? index) =>
      index is int && index >= 0 && index < _count
      ? (exists: true, value: _value[index])
      : (exists: false, value: null);

  /// Observes a position, including a position beyond the current length.
  LxListEntry<E> entry(int index) {
    RangeError.checkNotNegative(index, 'index');
    return LxListEntry._(this, index);
  }

  @override
  int get length {
    _observe(_ReadKind.length);
    return _count;
  }

  @override
  set length(int newLength) {
    mutate((list) => list.length = newLength);
  }

  @override
  E operator [](int index) {
    _observe(_ReadKind.element, index);
    return _value[index];
  }

  @override
  void operator []=(int index, E element) {
    _value[index] = element;
    _changed(address: index, single: true);
  }

  // Explicit range writes also invalidate equal-valued positions. On failure
  // compare actual snapshots: a backing list may already have changed.
  V _rangeEdit<V>(
    int start,
    int Function(int before, int after) end,
    V Function(List<E>) edit,
  ) {
    final before = _count;
    final V result;
    try {
      result = edit(_value);
    } catch (_) {
      _changed();
      rethrow;
    }
    final stop = end(before, _count);
    _changed(listRange: (start, stop));
    return result;
  }

  @override
  void add(E element) {
    final index = _count;
    _value.add(element);
    _changed(address: index, single: true);
  }

  @override
  void addAll(Iterable<E> iterable) {
    mutate((list) => list.addAll(iterable));
  }

  @override
  bool remove(Object? element) {
    final count = _count;
    final index = !_hasChannels ? -1 : _value.indexWhere((v) => v == element);
    final removed = _value.remove(element);
    if (removed) {
      _changed(written: (key) => key is int && key >= index && key < count);
    }
    return removed;
  }

  @override
  E removeAt(int index) {
    return _rangeEdit(index, max, (list) => list.removeAt(index));
  }

  @override
  void removeWhere(bool Function(E element) test) {
    mutate((list) => list.removeWhere(test));
  }

  @override
  void retainWhere(bool Function(E element) test) {
    mutate((list) => list.retainWhere(test));
  }

  @override
  void clear() {
    mutate((list) => list.clear());
  }

  @override
  void insert(int index, E element) {
    _rangeEdit(index, max, (list) => list.insert(index, element));
  }

  @override
  void insertAll(int index, Iterable<E> iterable) {
    _rangeEdit(
      index,
      (a, b) => a == b ? index : b,
      (list) => list.insertAll(index, iterable),
    );
  }

  @override
  void sort([int Function(E a, E b)? compare]) {
    mutate((list) => list.sort(compare));
  }

  @override
  void shuffle([Random? random]) {
    mutate((list) => list.shuffle(random));
  }

  @override
  E removeLast() {
    final index = _count - 1;
    final result = _value.removeLast();
    _changed(address: index, single: true);
    return result;
  }

  @override
  void setAll(int index, Iterable<E> iterable) {
    if (iterable is List<E>) {
      final end = index + iterable.length;
      _rangeEdit(index, (_, _) => end, (list) => list.setAll(index, iterable));
      return;
    }
    var written = 0;
    _rangeEdit(
      index,
      (_, _) => index + written,
      (list) => list.setAll(
        index,
        iterable.map((item) {
          written++;
          return item;
        }),
      ),
    );
  }

  @override
  void setRange(int start, int end, Iterable<E> iterable, [int skipCount = 0]) {
    _rangeEdit(
      start,
      (_, _) => end,
      (list) => list.setRange(start, end, iterable, skipCount),
    );
  }

  @override
  void removeRange(int start, int end) {
    _rangeEdit(
      start,
      (a, b) => a == b ? start : a,
      (list) => list.removeRange(start, end),
    );
  }

  @override
  void fillRange(int start, int end, [E? fill]) {
    _rangeEdit(
      start,
      (_, _) => end,
      (list) => list.fillRange(start, end, fill),
    );
  }

  @override
  void replaceRange(int start, int end, Iterable<E> newContents) {
    _rangeEdit(
      start,
      (a, b) => a == b ? end : max(a, b),
      (list) => list.replaceRange(start, end, newContents),
    );
  }

  @override
  E get first {
    _observe(_ReadKind.element, 0);
    return _value.first;
  }

  @override
  set first(E element) {
    _value.first = element;
    _changed(address: 0, single: true);
  }

  @override
  E get last {
    final n = length;
    _observe(_ReadKind.element, n - 1);
    return _value.last;
  }

  @override
  set last(E element) {
    _value.last = element;
    _changed(address: _count - 1, single: true);
  }

  @override
  bool get isEmpty {
    _observe(_ReadKind.empty);
    return _value.isEmpty;
  }

  @override
  bool get isNotEmpty => !isEmpty;

  @override
  Iterator<E> get iterator => value.iterator;

  @override
  E get single {
    if (length == 1) return this[0];
    return _value.single;
  }

  @override
  Iterable<E> get reversed => _CollectionIterable(() => value.reversed);

  @override
  bool contains(Object? element) => value.contains(element);

  @override
  E elementAt(int index) => this[index];

  @override
  bool every(bool Function(E element) test) => value.every(test);

  @override
  bool any(bool Function(E element) test) => value.any(test);

  @override
  E firstWhere(bool Function(E element) test, {E Function()? orElse}) =>
      value.firstWhere(test, orElse: orElse);

  @override
  E lastWhere(bool Function(E element) test, {E Function()? orElse}) =>
      value.lastWhere(test, orElse: orElse);

  @override
  E singleWhere(bool Function(E element) test, {E Function()? orElse}) =>
      value.singleWhere(test, orElse: orElse);

  @override
  int indexOf(E element, [int start = 0]) => value.indexOf(element, start);

  @override
  int lastIndexOf(E element, [int? start]) => value.lastIndexOf(element, start);

  @override
  int indexWhere(bool Function(E element) test, [int start = 0]) =>
      value.indexWhere(test, start);

  @override
  int lastIndexWhere(bool Function(E element) test, [int? start]) =>
      value.lastIndexWhere(test, start);

  @override
  E reduce(E Function(E value, E element) combine) => value.reduce(combine);

  @override
  T fold<T>(T initialValue, T Function(T previousValue, E element) combine) =>
      value.fold(initialValue, combine);

  @override
  Iterable<E> where(bool Function(E element) test) =>
      _CollectionIterable(() => value.where(test));

  @override
  Iterable<T> whereType<T>() => _CollectionIterable(() => value.whereType<T>());

  @override
  Iterable<T> map<T>(T Function(E e) f) =>
      _CollectionIterable(() => value.map(f));

  @override
  Iterable<T> expand<T>(Iterable<T> Function(E element) f) =>
      _CollectionIterable(() => value.expand(f));

  @override
  void forEach(void Function(E element) f) => value.forEach(f);

  @override
  String join([String separator = '']) => value.join(separator);

  @override
  Iterable<E> skip(int count) => _CollectionIterable(() => value.skip(count));

  @override
  Iterable<E> skipWhile(bool Function(E value) test) =>
      _CollectionIterable(() => value.skipWhile(test));

  @override
  Iterable<E> take(int count) => _CollectionIterable(() => value.take(count));

  @override
  Iterable<E> takeWhile(bool Function(E value) test) =>
      _CollectionIterable(() => value.takeWhile(test));

  @override
  List<E> toList({bool growable = true}) => value.toList(growable: growable);

  @override
  Set<E> toSet() => value.toSet();

  @override
  Iterable<E> followedBy(Iterable<E> other) =>
      _CollectionIterable(() => value.followedBy(other));

  @override
  Map<int, E> asMap() => _ListIndexMap(this);

  @override
  List<E> operator +(List<E> other) => value + other;

  @override
  List<E> sublist(int start, [int? end]) => value.sublist(start, end);

  @override
  Iterable<E> getRange(int start, int end) {
    RangeError.checkValidRange(start, end, _count);
    return _CollectionIterable(() => value.getRange(start, end));
  }

  @override
  List<R> cast<R>() => List.castFrom<E, R>(this);

  /// Replaces all current elements with [elements] in a single notification.
  void assign(Iterable<E> elements) {
    if (identical(elements, this) || identical(elements, _value)) return;
    final copy = List<E>.of(elements);
    mutate(
      (list) => list
        ..clear()
        ..addAll(copy),
    );
  }

  /// Replaces the list with a single [element].
  void assignOne(E element) {
    mutate(
      (list) => list
        ..clear()
        ..add(element),
    );
  }
}

class _ListIndexMap<E> extends UnmodifiableMapBase<int, E> {
  final LxList<E> list;
  _ListIndexMap(this.list);
  @override
  E? operator [](Object? key) {
    if (key is! int || key < 0) return null;
    list._observe(_ReadKind.element, key);
    return key < list._count ? list._value[key] : null;
  }

  @override
  Iterable<int> get keys =>
      _CollectionIterable(() => Iterable<int>.generate(list.length));
}

/// A reactive map that notifies observers on modification.
///
/// [LxMap] implements [Map] and intercepts all mutating operations
/// (`operator []=`, `remove`, `clear`, etc.) to trigger reactive updates.
///
/// ```dart
/// final settings = {'theme': 'dark'}.lx;
///
/// // Update triggers observers
/// settings['theme'] = 'light';
/// ```
///
/// {@category Reactive State}
class LxMap<K, V> extends LxVar<Map<K, V>>
    with _PreciseCollection<Map<K, V>, V>
    implements Map<K, V> {
  /// Creates a reactive map.
  ///
  /// Backed by [initial] if provided, otherwise an empty map.
  LxMap({Map<K, V>? initial, String? name, bool isSensitive = false})
    : _defaultBacking = initial == null,
      super(initial ?? <K, V>{}, name: name, isSensitive: isSensitive);

  /// Creates an [LxMap] from an existing [Map].
  factory LxMap.from(
    Map<K, V> other, {
    String? name,
    bool isSensitive = false,
  }) {
    return LxMap<K, V>(name: name, isSensitive: isSensitive)
      .._value.addAll(other);
  }

  bool _defaultBacking;
  @override
  bool get _standardAddresses => _defaultBacking;
  @override
  int get _count => _value.length;
  Iterable<Object?> get _orderedKeys => _value.keys;
  @override
  bool _existsAt(Object? key) => _value.containsKey(key);
  @override
  Object? _valueAt(Object? key) => _value[key];
  @override
  _Element _element(Object? key) =>
      (exists: _value.containsKey(key), value: _value[key]);

  @override
  void _setValueInternal(Map<K, V> val, {bool notifyListeners = true}) {
    if (!identical(val, _value)) _defaultBacking = false;
    super._setValueInternal(val, notifyListeners: notifyListeners);
  }

  /// Observes one key without owning its value.
  LxMapEntry<V> entry(K key) => LxMapEntry._(this, key);

  @override
  V? operator [](Object? key) {
    _observe(_ReadKind.element, key);
    return _value[key];
  }

  @override
  void operator []=(K key, V val) {
    _value[key] = val;
    _changed(address: key, single: true);
  }

  @override
  void addAll(Map<K, V> other) => addEntries(other.entries);
  @override
  void addEntries(Iterable<MapEntry<K, V>> entries) {
    final touched = !_hasChannels
        ? null
        : (_standardAddresses ? <Object?>{} : Set<Object?>.identity());
    try {
      for (final item in entries) {
        _value[item.key] = item.value;
        touched?.add(item.key);
      }
    } finally {
      _changed(written: touched?.contains);
    }
  }

  @override
  V? remove(Object? key) {
    if (!_value.containsKey(key)) return null;
    final old = _value.remove(key);
    _changed(address: key, single: true);
    return old;
  }

  @override
  void removeWhere(bool Function(K, V) test) =>
      mutate((m) => m.removeWhere(test));
  @override
  void clear() {
    if (_value.isEmpty) return;
    _value.clear();
    _changed();
  }

  @override
  V update(K key, V Function(V) update, {V Function()? ifAbsent}) {
    final result = _value.update(key, update, ifAbsent: ifAbsent);
    _changed(address: key, single: true);
    return result;
  }

  @override
  void updateAll(V Function(K, V) update) {
    final touched = !_hasChannels
        ? null
        : (_standardAddresses ? <Object?>{} : Set<Object?>.identity());
    try {
      _value.updateAll((key, old) {
        final next = update(key, old);
        touched?.add(key);
        return next;
      });
    } finally {
      _changed(written: touched?.contains);
    }
  }

  @override
  V putIfAbsent(K key, V Function() ifAbsent) {
    final hadKey = _value.containsKey(key);
    final result = _value.putIfAbsent(key, ifAbsent);
    if (!hadKey) _changed(address: key, single: true);
    return result;
  }

  @override
  bool containsKey(Object? key) {
    _observe(_ReadKind.membership, key);
    return _value.containsKey(key);
  }

  @override
  bool containsValue(Object? value) => this.value.containsValue(value);
  @override
  int get length {
    _observe(_ReadKind.length);
    return _count;
  }

  @override
  bool get isEmpty {
    _observe(_ReadKind.empty);
    return _value.isEmpty;
  }

  @override
  bool get isNotEmpty => !isEmpty;
  @override
  Iterable<K> get keys {
    _observe(_ReadKind.keys);
    return _CollectionIterable(() {
      _observe(_ReadKind.keys);
      return _value.keys;
    });
  }

  @override
  Iterable<V> get values {
    value;
    return _CollectionIterable(() => value.values);
  }

  @override
  Iterable<MapEntry<K, V>> get entries {
    value;
    return _CollectionIterable(() => value.entries);
  }

  @override
  void forEach(void Function(K, V) action) => value.forEach(action);
  @override
  Map<K2, V2> map<K2, V2>(MapEntry<K2, V2> Function(K, V) transform) =>
      value.map(transform);
  @override
  Map<RK, RV> cast<RK, RV>() => Map.castFrom<K, V, RK, RV>(this);

  /// Replaces all entries as one mutation.
  void assign(Map<K, V> other) {
    if (identical(other, this) || identical(other, _value)) return;
    mutate(
      (m) => m
        ..clear()
        ..addAll(other),
    );
  }
}

/// A reactive set that notifies observers on modification.
///
/// [LxSet] implements [Set] and intercepts all mutating operations
/// (add, remove, etc.) to trigger reactive updates.
///
/// {@category Reactive State}
class LxSet<E> extends LxVar<Set<E>> implements Set<E> {
  /// Creates a reactive set.
  ///
  /// Backed by [initial] if provided, otherwise an empty set.
  LxSet({Set<E>? initial, String? name, bool isSensitive = false})
    : super(initial ?? <E>{}, name: name, isSensitive: isSensitive);

  /// Creates an [LxSet] from an existing [Iterable].
  factory LxSet.from(
    Iterable<E> elements, {
    String? name,
    bool isSensitive = false,
  }) {
    return LxSet<E>(
      initial: Set<E>.from(elements),
      name: name,
      isSensitive: isSensitive,
    );
  }

  @override
  bool add(E value) {
    final result = _value.add(value);
    if (result) refresh();
    return result;
  }

  @override
  void addAll(Iterable<E> elements) {
    try {
      _value.addAll(elements);
    } finally {
      refresh();
    }
  }

  @override
  bool remove(Object? value) {
    final result = _value.remove(value);
    if (result) refresh();
    return result;
  }

  @override
  void removeWhere(bool Function(E) test) {
    try {
      _value.removeWhere(test);
    } finally {
      refresh();
    }
  }

  @override
  void retainWhere(bool Function(E) test) {
    try {
      _value.retainWhere(test);
    } finally {
      refresh();
    }
  }

  @override
  void removeAll(Iterable<Object?> elements) {
    try {
      _value.removeAll(elements);
    } finally {
      refresh();
    }
  }

  @override
  void retainAll(Iterable<Object?> elements) {
    try {
      _value.retainAll(elements);
    } finally {
      refresh();
    }
  }

  @override
  void clear() {
    _value.clear();
    refresh();
  }

  @override
  bool contains(Object? value) => this.value.contains(value);

  @override
  bool containsAll(Iterable<Object?> other) => value.containsAll(other);

  @override
  Set<E> intersection(Set<Object?> other) => value.intersection(other);

  @override
  Set<E> union(Set<E> other) => value.union(other);

  @override
  Set<E> difference(Set<Object?> other) => value.difference(other);

  @override
  E? lookup(Object? object) => value.lookup(object);

  @override
  Iterator<E> get iterator => value.iterator;

  @override
  int get length => value.length;

  @override
  bool get isEmpty => value.isEmpty;

  @override
  bool get isNotEmpty => value.isNotEmpty;

  @override
  E get first => value.first;

  @override
  E get last => value.last;

  @override
  E get single => value.single;

  @override
  Iterable<E> where(bool Function(E) test) => value.where(test);

  @override
  Iterable<T> whereType<T>() => value.whereType<T>();

  @override
  Iterable<T> map<T>(T Function(E) f) => value.map(f);

  @override
  Iterable<T> expand<T>(Iterable<T> Function(E) f) => value.expand(f);

  @override
  void forEach(void Function(E) f) => value.forEach(f);

  @override
  String join([String separator = '']) => value.join(separator);

  @override
  Iterable<E> skip(int count) => value.skip(count);

  @override
  Iterable<E> skipWhile(bool Function(E) test) => value.skipWhile(test);

  @override
  Iterable<E> take(int count) => value.take(count);

  @override
  Iterable<E> takeWhile(bool Function(E) test) => value.takeWhile(test);

  @override
  List<E> toList({bool growable = true}) => value.toList(growable: growable);

  @override
  Set<E> toSet() => value.toSet();

  @override
  bool any(bool Function(E) test) => value.any(test);

  @override
  bool every(bool Function(E) test) => value.every(test);

  @override
  T fold<T>(T initialValue, T Function(T, E) combine) =>
      value.fold(initialValue, combine);

  @override
  E reduce(E Function(E, E) combine) => value.reduce(combine);

  @override
  E elementAt(int index) => value.elementAt(index);

  @override
  E firstWhere(bool Function(E) test, {E Function()? orElse}) =>
      value.firstWhere(test, orElse: orElse);

  @override
  E lastWhere(bool Function(E) test, {E Function()? orElse}) =>
      value.lastWhere(test, orElse: orElse);

  @override
  E singleWhere(bool Function(E) test, {E Function()? orElse}) =>
      value.singleWhere(test, orElse: orElse);

  @override
  Iterable<E> followedBy(Iterable<E> other) => value.followedBy(other);

  @override
  Set<R> cast<R>() => value.cast<R>();

  /// Replaces all elements with [elements] in a single notification.
  void assign(Iterable<E> elements) {
    if (identical(elements, this) || identical(elements, _value)) return;
    final copy = List<E>.of(elements);
    _value
      ..clear()
      ..addAll(copy);
    refresh();
  }

  /// Replaces the set with a single [element].
  void assignOne(E element) {
    _value
      ..clear()
      ..add(element);
    refresh();
  }
}

/// Helper extensions for creating reactive collections.
///
/// {@category Reactive State}
extension LxListExtension<E> on List<E> {
  /// Converts this list into a reactive [LxList].
  LxList<E> get lx => LxList<E>.from(this);
}

/// Helper extensions for creating reactive maps.
///
/// {@category Reactive State}
extension LxMapExtension<K, V> on Map<K, V> {
  /// Converts this map into a reactive [LxMap].
  LxMap<K, V> get lx => LxMap<K, V>.from(this);
}

/// Helper extensions for creating reactive sets.
///
/// {@category Reactive State}
extension LxSetExtension<E> on Set<E> {
  /// Converts this set into a reactive [LxSet].
  LxSet<E> get lx => LxSet<E>.from(this);
}
