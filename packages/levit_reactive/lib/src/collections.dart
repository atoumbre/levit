import 'dart:math';

import 'base_types.dart';

/// A reactive list that notifies observers when modified.
///
/// [LxList] wraps a standard [List] and intercepts mutating methods (like `add`,
/// `remove`, `[]=` etc.) to automatically trigger notifications.
///
/// Use this collection when you need a list that updates the UI or triggers
/// effects whenever elements are added, removed, or changed.
///
/// ```dart
/// final items = <String>[].lx;
/// items.add('Hello'); // Notifies observers
/// ```
class LxList<E> extends LxVar<List<E>> implements List<E> {
  /// Creates a reactive list.
  ///
  /// If [initial] is provided, it is used as the backing list.
  /// Otherwise, an empty list is created.
  LxList([List<E>? initial, String? name]) : super(initial ?? <E>[]);

  /// Creates an [LxList] containing all [elements].
  factory LxList.from(Iterable<E> elements) {
    return LxList<E>(List<E>.from(elements));
  }

  // List interface implementation

  @override
  int get length => value.length;

  @override
  set length(int newLength) {
    value.length = newLength;
    refresh();
  }

  @override
  E operator [](int index) => value[index];

  @override
  void operator []=(int index, E element) {
    value[index] = element;
    refresh();
  }

  @override
  void add(E element) {
    value.add(element);
    refresh();
  }

  @override
  void addAll(Iterable<E> iterable) {
    value.addAll(iterable);
    refresh();
  }

  @override
  bool remove(Object? element) {
    final result = value.remove(element);
    if (result) refresh();
    return result;
  }

  @override
  E removeAt(int index) {
    final result = value.removeAt(index);
    refresh();
    return result;
  }

  @override
  void removeWhere(bool Function(E element) test) {
    value.removeWhere(test);
    refresh();
  }

  @override
  void retainWhere(bool Function(E element) test) {
    value.retainWhere(test);
    refresh();
  }

  @override
  void clear() {
    value.clear();
    refresh();
  }

  @override
  void insert(int index, E element) {
    value.insert(index, element);
    refresh();
  }

  @override
  void insertAll(int index, Iterable<E> iterable) {
    value.insertAll(index, iterable);
    refresh();
  }

  @override
  void sort([int Function(E a, E b)? compare]) {
    value.sort(compare);
    refresh();
  }

  @override
  void shuffle([Random? random]) {
    value.shuffle(random);
    refresh();
  }

  @override
  E removeLast() {
    final result = value.removeLast();
    refresh();
    return result;
  }

  @override
  void setAll(int index, Iterable<E> iterable) {
    value.setAll(index, iterable);
    refresh();
  }

  @override
  void setRange(int start, int end, Iterable<E> iterable, [int skipCount = 0]) {
    value.setRange(start, end, iterable, skipCount);
    refresh();
  }

  @override
  void removeRange(int start, int end) {
    value.removeRange(start, end);
    refresh();
  }

  @override
  void fillRange(int start, int end, [E? fill]) {
    value.fillRange(start, end, fill);
    refresh();
  }

  @override
  void replaceRange(int start, int end, Iterable<E> newContents) {
    value.replaceRange(start, end, newContents);
    refresh();
  }

  // Read-only List methods (delegate to underlying list)

  @override
  E get first => value.first;

  @override
  set first(E element) {
    value.first = element;
    refresh();
  }

  @override
  E get last => value.last;

  @override
  set last(E element) {
    value.last = element;
    refresh();
  }

  @override
  bool get isEmpty => value.isEmpty;

  @override
  bool get isNotEmpty => value.isNotEmpty;

  @override
  Iterator<E> get iterator => value.iterator;

  @override
  E get single => value.single;

  @override
  Iterable<E> get reversed => value.reversed;

  @override
  bool contains(Object? element) => value.contains(element);

  @override
  E elementAt(int index) => value.elementAt(index);

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
  Iterable<E> where(bool Function(E element) test) => value.where(test);

  @override
  Iterable<T> whereType<T>() => value.whereType<T>();

  @override
  Iterable<T> map<T>(T Function(E e) f) => value.map(f);

  @override
  Iterable<T> expand<T>(Iterable<T> Function(E element) f) => value.expand(f);

  @override
  void forEach(void Function(E element) f) => value.forEach(f);

  @override
  String join([String separator = '']) => value.join(separator);

  @override
  Iterable<E> skip(int count) => value.skip(count);

  @override
  Iterable<E> skipWhile(bool Function(E value) test) => value.skipWhile(test);

  @override
  Iterable<E> take(int count) => value.take(count);

  @override
  Iterable<E> takeWhile(bool Function(E value) test) => value.takeWhile(test);

  @override
  List<E> toList({bool growable = true}) => value.toList(growable: growable);

  @override
  Set<E> toSet() => value.toSet();

  @override
  Iterable<E> followedBy(Iterable<E> other) => value.followedBy(other);

  @override
  Map<int, E> asMap() => value.asMap();

  @override
  List<E> operator +(List<E> other) => value + other;

  @override
  List<E> sublist(int start, [int? end]) => value.sublist(start, end);

  @override
  Iterable<E> getRange(int start, int end) => value.getRange(start, end);

  @override
  List<R> cast<R>() => value.cast<R>();

  // Convenience methods

  /// Replaces all elements with [elements] in a single notification.
  ///
  /// More efficient than `clear()` followed by `addAll()`.
  void assign(Iterable<E> elements) {
    value
      ..clear()
      ..addAll(elements);
    refresh();
  }

  /// Replaces all elements with a single [element].
  ///
  /// Clears the list and adds [element].
  void assignOne(E element) {
    value
      ..clear()
      ..add(element);
    refresh();
  }
}

/// A reactive map that notifies observers when modified.
///
/// [LxMap] wraps a standard [Map] and intercepts mutating methods to
/// automatically trigger notifications.
///
/// Use this collection when you need a map that updates the UI or triggers
/// effects whenever entries are added, removed, or changed.
///
/// ```dart
/// final settings = <String, dynamic>{}.lx;
/// settings['theme'] = 'dark'; // Notifies observers
/// ```
class LxMap<K, V> extends LxVar<Map<K, V>> implements Map<K, V> {
  /// Creates a reactive map.
  ///
  /// If [initial] is provided, it is used as the backing map.
  /// Otherwise, an empty map is created.
  LxMap([Map<K, V>? initial, String? name]) : super(initial ?? <K, V>{});

  /// Creates an [LxMap] from an existing map.
  factory LxMap.from(Map<K, V> other) {
    return LxMap<K, V>(Map<K, V>.from(other));
  }

  // Map interface implementation

  @override
  V? operator [](Object? key) => value[key];

  @override
  void operator []=(K key, V val) {
    value[key] = val;
    refresh();
  }

  @override
  void addAll(Map<K, V> other) {
    value.addAll(other);
    refresh();
  }

  @override
  void addEntries(Iterable<MapEntry<K, V>> entries) {
    value.addEntries(entries);
    refresh();
  }

  @override
  V? remove(Object? key) {
    final result = value.remove(key);
    refresh();
    return result;
  }

  @override
  void removeWhere(bool Function(K key, V value) test) {
    value.removeWhere(test);
    refresh();
  }

  @override
  void clear() {
    value.clear();
    refresh();
  }

  @override
  V update(K key, V Function(V value) update, {V Function()? ifAbsent}) {
    final result = value.update(key, update, ifAbsent: ifAbsent);
    refresh();
    return result;
  }

  @override
  void updateAll(V Function(K key, V value) update) {
    value.updateAll(update);
    refresh();
  }

  @override
  V putIfAbsent(K key, V Function() ifAbsent) {
    final hadKey = value.containsKey(key);
    final result = value.putIfAbsent(key, ifAbsent);
    if (!hadKey) refresh();
    return result;
  }

  // Read-only Map methods (delegate to underlying map)

  @override
  bool containsKey(Object? key) => value.containsKey(key);

  @override
  bool containsValue(Object? val) => value.containsValue(val);

  @override
  int get length => value.length;

  @override
  bool get isEmpty => value.isEmpty;

  @override
  bool get isNotEmpty => value.isNotEmpty;

  @override
  Iterable<K> get keys => value.keys;

  @override
  Iterable<V> get values => value.values;

  @override
  Iterable<MapEntry<K, V>> get entries => value.entries;

  @override
  void forEach(void Function(K key, V value) action) => value.forEach(action);

  @override
  Map<K2, V2> map<K2, V2>(
          MapEntry<K2, V2> Function(K key, V value) transform) =>
      value.map(transform);

  @override
  Map<RK, RV> cast<RK, RV>() => value.cast<RK, RV>();

  // Convenience methods

  /// Replaces all entries with [other] in a single notification.
  ///
  /// Clears the map and adds all entries from [other].
  void assign(Map<K, V> other) {
    value
      ..clear()
      ..addAll(other);
    refresh();
  }
}

/// A reactive set that notifies observers when modified.
///
/// [LxSet] wraps a standard [Set] and intercepts mutating methods to
/// automatically trigger notifications.
///
/// Use this collection when you need a set that updates the UI or triggers
/// effects whenever elements are added or removed.
class LxSet<E> extends LxVar<Set<E>> implements Set<E> {
  /// Creates a reactive set.
  ///
  /// If [initial] is provided, it is used as the backing set.
  /// Otherwise, an empty set is created.
  LxSet([Set<E>? initial, String? name]) : super(initial ?? <E>{});

  /// Creates an [LxSet] from an existing iterable.
  factory LxSet.from(Iterable<E> elements) {
    return LxSet<E>(Set<E>.from(elements));
  }

  // Set interface implementation

  @override
  bool add(E value) {
    final result = this.value.add(value);
    if (result) refresh();
    return result;
  }

  @override
  void addAll(Iterable<E> elements) {
    value.addAll(elements);
    refresh();
  }

  @override
  bool remove(Object? value) {
    final result = this.value.remove(value);
    if (result) refresh();
    return result;
  }

  @override
  void removeWhere(bool Function(E) test) {
    value.removeWhere(test);
    refresh();
  }

  @override
  void retainWhere(bool Function(E) test) {
    value.retainWhere(test);
    refresh();
  }

  @override
  void removeAll(Iterable<Object?> elements) {
    value.removeAll(elements);
    refresh();
  }

  @override
  void retainAll(Iterable<Object?> elements) {
    value.retainAll(elements);
    refresh();
  }

  @override
  void clear() {
    value.clear();
    refresh();
  }

  // Read-only Set methods (delegate to underlying set)

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

  // Convenience methods

  /// Replaces all elements with [elements] in a single notification.
  ///
  /// Clears the set and adds all elements from [elements].
  void assign(Iterable<E> elements) {
    value
      ..clear()
      ..addAll(elements);
    refresh();
  }

  /// Replaces all elements with a single [element].
  ///
  /// Clears the set and adds [element].
  void assignOne(E element) {
    value
      ..clear()
      ..add(element);
    refresh();
  }
}

/// Extension to create [LxList].
extension LxListExtension<E> on List<E> {
  /// Creates an [LxList] from this list.
  LxList<E> get lx => LxList<E>.from(this);
}

/// Extension to create [LxMap].
extension LxMapExtension<K, V> on Map<K, V> {
  /// Creates an [LxMap] from this map.
  LxMap<K, V> get lx => LxMap<K, V>.from(this);
}

/// Extension to create [LxSet].
extension LxSetExtension<E> on Set<E> {
  /// Creates an [LxSet] from this set.
  LxSet<E> get lx => LxSet<E>.from(this);
}
