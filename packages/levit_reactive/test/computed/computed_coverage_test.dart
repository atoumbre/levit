import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('LxComputed Coverage', () {
    test('LxComputed handles synchronous errors during read (no listener)', () {
      final computed = LxComputed(() {
        throw 'Sync Error';
      });

      // When accessed without listeners (proxy=null), it computes immediately.
      expect(computed.value, isA<LxError>());
      expect((computed.value as LxError).error, 'Sync Error');
    });

    test('LxComputed handles synchronous errors during read while active', () {
      final computed = LxComputed(() {
        throw 'Nested Error';
      });

      // active read means we are inside another reactive context
      final wrapper = LxComputed(() {
        return computed.value;
      });

      // This triggers the _computeSafe or try/catch block inside value getter when active
      expect(wrapper.value, isA<LxSuccess>());
      final inner = (wrapper.value as LxSuccess).value;
      expect(inner, isA<LxError>());
      expect((inner as LxError).error, 'Nested Error');
    });

    test('LxComputed optimizes dependency tracking for > 8 dependencies', () {
      // Create 10 dependencies
      final deps = List.generate(10, (i) => i.lx);

      final computed = LxComputed(() {
        // Access all to trigger _add -> _listDeps.length >= 8 -> _useSet = true
        return deps.map((d) => d.value).join(',');
      });

      expect(computed.value, isA<LxSuccess<String>>());
      expect(
          (computed.value as LxSuccess<String>).value, '0,1,2,3,4,5,6,7,8,9');

      // Verify updates still work
      deps[9].value = 99;
      expect(
          (computed.value as LxSuccess<String>).value, '0,1,2,3,4,5,6,7,8,99');
    });

    test('LxFunctionExtension creates computed', () {
      final c1 = 10.lx;
      final computed = (() => c1.value * 2).lx;
      expect(computed.value, isA<LxSuccess<int>>());
      expect((computed.value as LxSuccess<int>).value, 20);
    });

    test('LxComputed refresh and transform coverage', () {
      final c1 = 0.lx;
      final computed = LxComputed(() => c1.value);
      computed.refresh(); // Hit refresh
      expect((computed.value as LxSuccess).value, 0);

      // Hit refresh while active
      final sub = computed.stream.listen((_) {});
      computed.refresh();
      sub.cancel();

      // Hit transform
      final transformed =
          computed.transform((s) => s.map((v) => v.valueOrNull));
      expect(transformed, isA<LxStream>());
    });

    test('LxComputed _add useSet branch coverage', () {
      final deps = List.generate(20, (i) => i.lx);
      final computed = LxComputed(() {
        // Access many times to force set jump and then use set
        for (final d in deps) {
          d.value;
        }
        return 0;
      });
      // First call triggers jump to set
      expect((computed.value as LxSuccess).value, 0);

      // Force dirty and recompute to use the set path directly
      deps[0].value = 1;
      expect((computed.value as LxSuccess).value, 0);
    });

    test('LxComputed error path with proxy coverage', () {
      final c1 = 0.lx;
      final computed = LxComputed(() {
        if (c1.value == 1) throw 'Proxy error';
        return 0;
      });

      // No proxy
      expect(computed.value, isA<LxSuccess>());

      // With proxy, trigger error (hits line 218)
      c1.value = 1;
      final wrapper = LxComputed(() {
        // Proxy is active here
        return computed.value;
      });
      final val = wrapper.value;
      expect(val, isA<LxSuccess>());
      expect((val as LxSuccess).value, isA<LxError>());

      // Trigger line 206 (pull-on-read throws)
      final directThrow = LxComputed(() {
        throw 'Direct';
      });
      expect(directThrow.value, isA<LxError>());
    });
  });
}
