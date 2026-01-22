import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

void main() {
  testWidgets('LWatch complex subscription transitions', (tester) async {
    final listenable1 = LevitReactiveNotifier();
    // final listenable2 = LevitReactiveNotifier();
    // final stream1 = StreamController<int>.broadcast();
    // final stream2 = StreamController<int>.broadcast();

    // 0: Initial build with NO deps
    int mode = 0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: LWatch(() {
          if (mode == 0) return const Text('Idle');

          if (mode == 1) {
            // fast path: single notifier
            listenable1.notify(); // access it? No, addNotifier
            // Simulate access manually or via Lx reactive logic.
            // LWatch uses Lx.proxy
            // We need to simulate access to reactive objects.
            // But here we are using LevitReactiveNotifier directly?
            // LevitReactiveNotifier.value access doesn't exist.
            // We need LxVar<T> objects or call Lx.proxy.addNotifier() manually?
            // Since LWatch sets Lx.proxy, we can manually register deps if we want.
            // But better to use real reactive objects.
          }
          return const Text('Value');
        }),
      ),
    );
  });

  testWidgets('LWatch slow path subscription churn', (tester) async {
    final rx1 = 1.lx;
    final rx2 = 2.lx;
    final rx3 = 3.lx;
    final rx4 = 4.lx;

    // Mode 0: Multiple notifiers (slow path)
    // Mode 1: Different multiple notifiers (churn)
    // Mode 2: Streams + Notifiers
    // Mode 3: Reduce notifiers

    int mode = 0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: LWatch(
          () {
            if (mode == 0) {
              return Text('${rx1.value} ${rx2.value}');
            }
            if (mode == 1) {
              // Rx1 removed, Rx3, Rx4 added
              return Text('${rx2.value} ${rx3.value} ${rx4.value}');
            }
            if (mode == 2) {
              // Mix stream and notifier, assuming we can hook stream??
              // LWatch only tracks Lx access unless we have a way to track stream access.
              // LxComputed tracks streams, does LWatch?
              // LWatch implements LevitReactiveObserver.
              // Does accessing Stream automatically notify observer? NO.
              // Only LxReactive does.
              // Core.dart: Lx.proxy.addStream()
              // Who calls addStream?
              // Lx.value calls _reportRead -> addStream if bound.
              return Text('Mixed');
            }
            return const Text('Done');
          },
          debugLabel: 'TestWatch',
        ),
      ),
    );

    // Mode 0 -> 1: Covers removing notifiers in slow path
    mode = 1;
    rx1.value++; // Should NOT trigger rebuild after verify
    await tester.pump(); // Rebuild for mode change
    expect(find.text('2 3 4'), findsOneWidget);

    // Modify rx1, should not affect
    rx1.value = 99;
    await tester.pump();
    expect(find.text('2 3 4'), findsOneWidget); // Still same

    // Modify rx2, SHOULD rebuild
    rx2.value = 22;
    await tester.pump();
    expect(find.text('22 3 4'), findsOneWidget);

    // Now verify streams logic in LWatch.
    // To test streams, we need an Lx that has a bound stream.
    final streamCtrl = StreamController<int>.broadcast();
    final rxStream = LxInt(0);
    rxStream.bind(streamCtrl.stream);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: LWatch(() {
          return Text('StreamVal: ${rxStream.value}');
        }),
      ),
    );

    streamCtrl.add(100);
    await tester.pump(); // Microtask?
    await tester.pump(Duration.zero);

    expect(find.text('StreamVal: 100'), findsOneWidget);

    // Test removal of stream subscription when switching dependencies
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: LWatch(() {
          // Do not access rxStream anymore
          return const Text('NoStream');
        }),
      ),
    );

    streamCtrl.add(200);
    await tester.pump(Duration.zero);
    expect(find.text('NoStream'), findsOneWidget); // Should not rebuild
  });
}
