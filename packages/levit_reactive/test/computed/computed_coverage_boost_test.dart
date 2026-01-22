import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  group('LxComputed value getter coverage', () {
    tearDown(() {
      Lx.clearMiddlewares();
    });

    test('value getter succeeds when proxy is active', () {
      final source = 10.lx;
      final computed = LxComputed<int>(() => source.value * 2);

      // Set up a proxy
      final tracker = _MockObserver();
      Lx.proxy = tracker;

      try {
        final result = computed.value;

        expect(result, 20);
      } finally {
        Lx.proxy = null;
      }
    });
  });

  group('_DependencyTracker Set mode coverage', () {
    test('switches to Set mode when more than 8 dependencies', () {
      // Create 10 sources to trigger Set mode
      final sources = List.generate(10, (i) => i.lx);

      // Create computed that depends on all of them
      final computed = LxComputed<int>(() {
        int sum = 0;
        for (final s in sources) {
          sum += s.value;
        }
        return sum;
      });

      // Activate to register dependencies
      computed.stream.listen((_) {});

      // Access computed value
      expect(computed.value, 45); // sum 0..9 = 45

      // Change first source to verify tracking works
      sources[0].value = 100;
      expect(computed.value, 145);

      // Change last source
      sources[9].value = 100;
      expect(computed.value, 236); // 100 + 1..8 + 100 = 236

      for (final s in sources) {
        s.close();
      }
      computed.close();
    });

    test('adds to Set after switching mode', () {
      // Create 9 sources (will switch to Set on 9th add)
      final sources = List.generate(12, (i) => i.lx);

      final computed = LxComputed<int>(() {
        int sum = 0;
        for (final s in sources) {
          sum += s.value;
        }
        return sum;
      });

      // Activate
      computed.stream.listen((_) {});

      // sum(0..11) = 66
      expect(computed.value, 66);

      // Update multiple sources
      sources[10].value = 100;
      sources[11].value = 200;

      // 0+1+..+9 + 100 + 200 = 345
      expect(computed.value, 345);

      for (final s in sources) {
        s.close();
      }
      computed.close();
    });
  });
}

class _MockObserver implements LevitReactiveObserver {
  final List<Stream> streams = [];
  final List<LevitReactiveNotifier> notifiers = [];

  @override
  void addStream<T>(Stream<T> stream) {
    streams.add(stream);
  }

  @override
  void addNotifier(LevitReactiveNotifier notifier) {
    notifiers.add(notifier);
  }

  @override
  void addReactive(LxReactive reactive) {}
}
