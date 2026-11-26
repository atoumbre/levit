import 'dart:async';
import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('LxBool', () {
    test('supports named metadata parameters and asReadable view', () {
      final flag = LxBool(false, name: 'isReady', isSensitive: true);
      expect(flag.value, isFalse);
      expect(flag.name, 'isReady');
      expect(flag.isSensitive, isTrue);
      expect(flag.asReadable, same(flag));
    });

    test('initial value can be set', () {
      final flag = LxBool(true);
      expect(flag.value, isTrue);
    });

    test('toggle works and triggers stream', () async {
      final flag = LxBool(false);
      final triggered = <bool>[];
      flag.stream.listen((v) => triggered.add(v));

      flag.toggle();

      await Future.delayed(Duration.zero);
      expect(triggered, equals([true]));
      expect(flag.value, isTrue);

      flag.toggle();
      await Future.delayed(Duration.zero);
      expect(triggered, equals([true, false]));
      expect(flag.value, isFalse);
    });

    test('setTrue works', () {
      final flag = LxBool(false);
      flag.setTrue();
      expect(flag.value, isTrue);
    });

    test('setFalse works', () {
      final flag = LxBool(true);
      flag.setFalse();
      expect(flag.value, isFalse);
    });

    test('setting same value does not trigger stream', () async {
      final flag = LxBool(true);
      final triggered = <bool>[];
      flag.stream.listen((_) => triggered.add(true));

      flag.setTrue(); // Already true

      await Future.delayed(Duration.zero);
      expect(triggered, isEmpty);
    });

    test('isTrue and isFalse getters work', () {
      final flag = LxBool(true);
      expect(flag.isTrue, isTrue);
      expect(flag.isFalse, isFalse);

      flag.toggle();
      expect(flag.isTrue, isFalse);
      expect(flag.isFalse, isTrue);
    });

    test('.lxBool extension works', () {
      final flag = false.lx;
      expect(flag, isA<LxBool>());
      expect(flag.value, isFalse);

      flag.toggle();
      expect(flag.value, isTrue);
    });
    test('LxBool alias shares operations and lifecycle hooks with LxVar', () {
      var listened = false;
      final LxVar<bool> flag = LxBool(false, onListen: () => listened = true);
      final LxBool aliased = flag;
      void listener() {}
      aliased.addListener(listener);
      expect(listened, isTrue);

      aliased.toggle();
      expect(flag.isTrue, isTrue);

      aliased.removeListener(listener);
      aliased.close();
    });
  });
}
