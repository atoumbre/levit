import 'dart:async';

import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

final class _CustomReactive implements LxReactive<int> {
  final StreamController<int> _controller = StreamController<int>.broadcast();

  @override
  int value = 0;

  @override
  final int id = 1;

  @override
  String? name;

  @override
  String? ownerId;

  @override
  bool isSensitive = false;

  bool closed = false;

  @override
  Stream<int> get stream => _controller.stream;

  @override
  void addListener(void Function() listener) {}

  @override
  void removeListener(void Function() listener) {}

  @override
  void refresh() {}

  @override
  void close() {
    closed = true;
    _controller.close();
  }
}

void main() {
  test('constructs lazily and reuses one reactive per key', () {
    var builds = 0;
    final family = LxFamily<String, LxVar<int>>((key) {
      builds++;
      return key.length.lx;
    });

    expect(family.length, 0);
    final first = family('sku');
    final again = family('sku');
    final other = family('other');

    expect(identical(first, again), isTrue);
    expect(identical(first, other), isFalse);
    expect(builds, 2);
    expect(family.keys, containsAll(<String>['sku', 'other']));
    family.close();
    expect(first.isDisposed, isTrue);
    expect(other.isDisposed, isTrue);
  });

  test('invalidate closes an entry and recreates it on next access', () {
    final family = LxFamily<int, LxVar<int>>((key) => key.lx);
    final first = family(1);

    expect(family.invalidate(2), isFalse);
    expect(family.invalidate(1), isTrue);
    expect(first.isDisposed, isTrue);

    final second = family(1);
    expect(identical(first, second), isFalse);
    family.invalidateAll();
    expect(family.length, 0);
    expect(second.isDisposed, isTrue);
  });

  test('whenInactive waits for listeners to leave before eviction', () async {
    final family = LxFamily<String, LxVar<int>>(
      (_) => 0.lx,
      eviction: const LxFamilyEviction.whenInactive(
        gracePeriod: Duration(milliseconds: 10),
      ),
    );
    final value = family('active');
    void listener() {}
    value.addListener(listener);

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(family.containsKey('active'), isTrue);

    value.removeListener(listener);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(family.containsKey('active'), isFalse);
    expect(value.isDisposed, isTrue);
    family.close();
  });

  test('zero-grace entries can become active before their eviction timer',
      () async {
    final family = LxFamily<int, LxVar<int>>(
      (key) => key.lx,
      eviction: const LxFamilyEviction.whenInactive(),
    );
    final value = family(1);
    void listener() {}
    value.addListener(listener);

    await Future<void>.delayed(Duration.zero);
    expect(family.containsKey(1), isTrue);

    value.removeListener(listener);
    await Future<void>.delayed(Duration.zero);
    expect(family.containsKey(1), isFalse);
    family.close();
  });

  test('custom reactive entries use deterministic timed eviction', () async {
    final family = LxFamily<String, _CustomReactive>(
      (_) => _CustomReactive(),
      eviction: const LxFamilyEviction.whenInactive(),
    );
    final value = family('custom');

    await Future<void>.delayed(Duration.zero);

    expect(family.containsKey('custom'), isFalse);
    expect(value.closed, isTrue);
    family.close();
  });

  test('diagnostic names do not expose raw keys by default', () {
    final family = LxFamily<String, LxVar<int>>(
      (_) => 0.lx,
      name: 'stock',
    );
    final value = family('customer-secret');

    expect(value.name, startsWith('stock['));
    expect(value.name, isNot(contains('customer-secret')));
    family.close();
  });

  test('safe debug key formatter and formatter fallback are supported', () {
    final named = LxFamily<String, LxVar<int>>(
      (_) => 0.lx,
      name: 'stock',
      debugKey: (_) => 'safe',
    );
    expect(named('raw').name, 'stock[safe]');
    named.close();

    final fallback = LxFamily<String, LxVar<int>>(
      (_) => 0.lx,
      name: 'stock',
      debugKey: (_) => throw StateError('formatter failed'),
    );
    expect(fallback('raw').name, 'stock[key]');
    fallback.close();
  });

  test('closed entries are recreated and a closed family is terminal', () {
    final family = LxFamily<int, LxVar<int>>((key) => key.lx);
    final first = family(1)..close();
    final second = family(1);
    expect(identical(first, second), isFalse);

    family.close();
    expect(family.isDisposed, isTrue);
    expect(second.isDisposed, isTrue);
    expect(() => family(2), throwsStateError);
    family.close();
  });
}
