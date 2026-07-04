import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('LxComputed Dependency Tracking Optimization', () {
    test('LxComputed optimizes dependency tracking for > 8 dependencies', () {
      final deps = List.generate(10, (i) => i.lx);
      final computed = LxComputed(() => deps.map((d) => d.value).join(','));
      expect(computed.value, '0,1,2,3,4,5,6,7,8,9');
      deps[9].value = 99;
      expect(computed.value, '0,1,2,3,4,5,6,7,8,99');
    });

    test('LxComputed _add useSet branch coverage', () {
      final deps = List.generate(20, (i) => i.lx);
      final computed = LxComputed(() {
        for (final d in deps) {
          d.value;
        }
        return 0;
      });
      expect(computed.value, 0);
      deps[0].value = 1;
      expect(computed.value, 0);
    });
  });

  group('_DependencyTracker Set Mode', () {
    test('switches to Set mode when more than 8 dependencies', () {
      final sources = List.generate(10, (i) => i.lx);
      final computed = LxComputed<int>(() {
        int sum = 0;
        for (final s in sources) {
          sum += s.value;
        }
        return sum;
      });
      computed.stream.listen((_) {});
      expect(computed.value, 45);
      sources[0].value = 100;
      expect(computed.value, 145);
      sources[9].value = 100;
      expect(computed.value, 236);
    });

    test('adds to Set after switching mode', () {
      final sources = List.generate(12, (i) => i.lx);
      final computed = LxComputed<int>(() {
        int sum = 0;
        for (final s in sources) {
          sum += s.value;
        }
        return sum;
      });
      computed.stream.listen((_) {});
      expect(computed.value, 66);
      sources[10].value = 100;
      sources[11].value = 200;
      expect(computed.value, 345);
    });
  });
}
