import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  test(
    'borrows a readable source, including null, and releases only its listener',
    () async {
      final source = LxVar<int?>(null);
      final LxReadable<int?> readable = source;
      final adapter = readable.asValueListenable();
      expect(source.hasListener, isFalse);
      expect(adapter.value, isNull);
      final values = <int?>[];
      void changed() => values.add(adapter.value);
      adapter.addListener(changed);
      source.value = 1;
      source.value = null;
      expect(values, [1, null]);
      adapter.removeListener(changed);
      expect(source.hasListener, isFalse);
      source.value = 2;
      expect(adapter.value, 2);
      adapter.addListener(changed);
      adapter.dispose();
      adapter.dispose();
      adapter.removeListener(changed);
      expect(source.hasListener, isFalse);
      expect(source.isDisposed, isFalse);
      source.value = 3;
      expect(values, [1, null]);
      expect(() => adapter.value, throwsStateError);
      expect(() => adapter.addListener(changed), throwsStateError);
      await source.close();
    },
  );

  test(
    'duplicate Flutter listeners and mutable refresh notifications are preserved',
    () async {
      final source = <int>[].lx;
      final adapter = source.asValueListenable();
      var notifications = 0;
      void changed() => notifications++;
      adapter.addListener(changed);
      adapter.addListener(changed);
      source.add(1);
      expect(notifications, 2);
      expect(adapter.value, [1]);
      adapter.removeListener(changed);
      source.refresh();
      expect(notifications, 3);
      adapter.removeListener(changed);
      expect(source.hasListener, isFalse);
      source.add(2);
      expect(notifications, 3);
      adapter.dispose();
      await source.close();
    },
  );

  test('disposal inside a notification suppresses later callbacks', () async {
    final source = 0.lx;
    final adapter = source.asValueListenable();
    var lateCalls = 0;
    adapter.addListener(adapter.dispose);
    adapter.addListener(() => lateCalls++);
    source.value = 1;
    expect(lateCalls, 0);
    expect(adapter.isDisposed, isTrue);
    expect(source.hasListener, isFalse);
    source.value = 2;
    await source.close();
  });

  test(
    'controller ownership closes an adapter while its borrowed source lives',
    () async {
      final scope = LevitScope.root('adapter');
      final source = 0.lx;
      final owner = scope.put(_AdapterOwner.new);
      final adapter = owner.own(source.asValueListenable());
      adapter.addListener(() {});
      await scope.dispose();
      expect(adapter.isDisposed, isTrue);
      expect(source.hasListener, isFalse);
      expect(source.isDisposed, isFalse);
      await source.close();
    },
  );

  test('a deferred stream handle stays connected through restart', () async {
    var generation = 0;
    final stream = LxStream<int>.defer(
      () => Stream.value(++generation),
      completionPolicy: LxStreamCompletionPolicy.retain,
    );
    final adapter = stream.asValueListenable();
    final statuses = <LxStatus<int>>[];
    adapter.addListener(() => statuses.add(adapter.value));
    await Future<void>.delayed(Duration.zero);
    expect(adapter.value, isA<LxSuccess<int>>());
    expect((adapter.value as LxSuccess<int>).value, 1);
    stream.restartDeferred(() => Stream.value(++generation));
    await Future<void>.delayed(Duration.zero);
    expect(adapter.value, isA<LxSuccess<int>>());
    expect((adapter.value as LxSuccess<int>).value, 2);
    expect(statuses.any((s) => s is LxSuccess<int> && s.value == 2), isTrue);
    adapter.dispose();
    await stream.close();
  });

  testWidgets(
    'ValueListenableBuilder rebuilds, then unmount releases subscription',
    (tester) async {
      final source = 1.lx;
      final adapter = source.asValueListenable();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ValueListenableBuilder<int>(
            valueListenable: adapter,
            builder: (_, value, __) => Text('$value'),
          ),
        ),
      );
      source.value = 2;
      await tester.pump();
      expect(find.text('2'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(source.hasListener, isFalse);
      adapter.dispose();
      expect(source.isDisposed, isFalse);
      await source.close();
    },
  );
}

class _AdapterOwner extends LevitController {}
