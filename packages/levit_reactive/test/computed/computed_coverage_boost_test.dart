import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  group('LxComputed value getter coverage', () {
    tearDown(() {
      Lx.clearMiddlewares();
    });

    test('value getter catches error with graph change middleware', () {
      // Register a graph change middleware to trigger the code path
      final middleware = _GraphMiddleware();
      Lx.addMiddleware(middleware);

      // Create a computed that throws
      final computed = LxComputed<int>(() => throw 'computation error');

      // Access value - should return LxError, not throw
      final result = computed.value;

      expect(result, isA<LxError<int>>());
      expect((result as LxError).error, 'computation error');

      Lx.removeMiddleware(middleware);
    });

    test('value getter catches error when proxy is active', () {
      // Create outer computed that accesses inner throwing computed
      late LxComputed<int> inner;
      inner = LxComputed<int>(() => throw 'inner error');

      // Create an LWatch-like proxy
      final tracker = _MockObserver();
      Lx.proxy = tracker;

      try {
        // Access value while proxy is active
        final result = inner.value;

        expect(result, isA<LxError<int>>());
        expect((result as LxError).error, 'inner error');
      } finally {
        Lx.proxy = null;
      }
    });

    test('value getter succeeds when proxy is active', () {
      final source = 10.lx;
      final computed = LxComputed<int>(() => source.value * 2);

      // Set up a proxy
      final tracker = _MockObserver();
      Lx.proxy = tracker;

      try {
        final result = computed.value;

        expect(result, isA<LxSuccess<int>>());
        expect((result as LxSuccess).value, 20);
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
      expect(computed.computedValue, 45); // sum 0..9 = 45

      // Change first source to verify tracking works
      sources[0].value = 100;
      expect(computed.computedValue, 145);

      // Change last source
      sources[9].value = 100;
      expect(computed.computedValue, 236); // 100 + 1..8 + 100 = 236

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
      expect(computed.computedValue, 66);

      // Update multiple sources
      sources[10].value = 100;
      sources[11].value = 200;

      // 0+1+..+9 + 100 + 200 = 345
      expect(computed.computedValue, 345);

      for (final s in sources) {
        s.close();
      }
      computed.close();
    });
  });
}

class _GraphMiddleware extends LevitStateMiddleware {
  @override
  void Function(LxReactive computed, List<LxReactive> dependencies)?
      get onGraphChange => (computed, deps) {
            // Just observe, don't do anything
          };
}

class _MockObserver implements LevitStateObserver {
  final List<Stream> streams = [];
  final List<LevitStateNotifier> notifiers = [];

  @override
  void addStream<T>(Stream<T> stream) {
    streams.add(stream);
  }

  @override
  void addNotifier(LevitStateNotifier notifier) {
    notifiers.add(notifier);
  }

  @override
  void addReactive(LxReactive reactive) {}
}
