import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';
import 'package:levit_reactive/spi.dart';

class _Graphs extends LevitReactiveMiddleware {
  final events = <List<LxReactive>>[];
  @override
  void Function(LxReactive, List<LxReactive>) get onGraphChange =>
      (_, dependencies) => events.add(List.of(dependencies));
}

void main() {
  for (final diagnostics in [false, true]) {
    test('dynamic reads stay exact with diagnostics=$diagnostics', () async {
      final graphs = _Graphs();
      if (diagnostics) Lx.addMiddleware(graphs);
      addTearDown(() => Lx.removeMiddleware(graphs));
      final sources = List.generate(20, (i) => i.lx);
      final revision = 0.lx;
      var order = List.generate(20, (i) => i);
      var runs = 0;
      final derived = LxComputed(() {
        revision.value;
        runs++;
        return order.fold(0, (sum, index) => sum + sources[index].value);
      });
      var observed = derived.value;
      void consume() => observed = derived.value;
      derived.addListener(consume);
      void verify() {
        expect(observed, order.fold(0, (sum, i) => sum + sources[i].value));
        for (var i = 0; i < sources.length; i++) {
          expect(
            sources[i].hasListener,
            order.contains(i),
            reason: 'source $i',
          );
        }
      }

      for (var i = 0; i < 3; i++) {
        sources[0].value++;
        verify();
      }
      final stableEvents = graphs.events.length;
      sources[0].value++;
      expect(graphs.events.length, stableEvents);
      // Reordered same set, repeated non-adjacent reads, shorter prefix, empty
      // suffix, replacement, then growth across the small-graph threshold.
      for (final next in [
        List.generate(20, (i) => 19 - i),
        [19, 18, 19, 18],
        [19],
        <int>[],
        [3],
        List.generate(20, (i) => i),
      ]) {
        order = next;
        revision.value++;
        verify();
        final before = runs;
        final removed = sources.indexWhere((s) => !s.hasListener);
        if (removed >= 0) {
          sources[removed].value++;
          expect(runs, before);
        }
      }
      if (diagnostics) expect(graphs.events.length, greaterThan(stableEvents));

      derived.removeListener(consume);
      expect(sources.every((s) => !s.hasListener), isTrue);
      sources[0].value++;
      order = [4, 5];
      derived.addListener(consume);
      consume();
      verify();
      await derived.close();
      expect(sources.every((s) => !s.hasListener), isTrue);
      await revision.close();
      for (final source in sources) {
        await source.close();
      }
    });
  }

  test('stable membership still updates upstream graph depth', () async {
    final source = 0.lx;
    final derived = LxComputed(() => source.value);
    derived.addListener(() => derived.value);
    expect(derived.graphDepth, 1);
    LxSpi.setGraphDepth(source, 7);
    source.value++;
    expect(derived.graphDepth, 8);
    LxSpi.setGraphDepth(source, 0);
    source.value++;
    expect(derived.graphDepth, 1);
    await derived.close();
    await source.close();
  });

  test('failed capture does not contaminate a later computation', () async {
    final source = 0.lx;
    final other = 10.lx;
    final broken = LxComputed(() {
      final value = source.value;
      if (value == 1) {
        other.value;
        throw StateError('failed capture');
      }
      return value;
    });
    broken.addListener(() => broken.value);
    expect(() => source.value = 1, throwsStateError);
    final unrelated = LxComputed(() => other.value * 2);
    var observed = 20;
    unrelated.addListener(() => observed = unrelated.value);
    source.value = 2;
    expect(broken.value, 2);
    expect(observed, 20);
    other.value = 11;
    expect(observed, 22);
    await broken.close();
    expect(source.hasListener, isFalse);
    await unrelated.close();
    expect(other.hasListener, isFalse);
    await source.close();
    await other.close();
  });

  test(
    'eager value listener can close during dependency replacement',
    () async {
      final choose = false.lx;
      final first = 1.lx;
      final second = 2.lx;
      final derived = LxComputed(
        () => choose.value ? second.value : first.value,
        eager: true,
      );
      Future<void>? closing;
      derived.addListener(() => closing = derived.close());
      choose.value = true;
      await closing;
      expect(choose.hasListener, isFalse);
      expect(first.hasListener, isFalse);
      expect(second.hasListener, isFalse);
      await choose.close();
      await first.close();
      await second.close();
    },
  );
}
