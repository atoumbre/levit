import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_kit/src/widgets/l_keep_alive.dart';
import 'package:levit_flutter_kit/src/widgets/l_list_item_monitor.dart';

void main() {
  group('LKeepAlive', () {
    testWidgets('keeps child alive when scrolled out of view', (tester) async {
      final disposeCalls = <int>[];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ListView.builder(
            itemExtent: 100, // Fixed height to easily scroll out
            itemBuilder: (context, index) {
              return LKeepAlive(
                child: LListItemMonitor(
                  onDispose: () => disposeCalls.add(index),
                  child: Text('Item $index'),
                ),
              );
            },
          ),
        ),
      );

      // Verify item 0 is built
      expect(find.text('Item 0'), findsOneWidget);

      // Scroll far away so item 0 would normally be disposed
      await tester.drag(find.text('Item 0'), const Offset(0, -1000));
      await tester.pump();

      // Verify item 0 was NOT disposed (captured by list item monitor)
      expect(disposeCalls, isNot(contains(0)));
    });

    testWidgets('disposes child when keepAlive is false', (tester) async {
      final disposeCalls = <int>[];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ListView.builder(
            itemExtent: 100,
            itemBuilder: (context, index) {
              return LKeepAlive(
                keepAlive: false, // Don't keep alive
                child: LListItemMonitor(
                  onDispose: () => disposeCalls.add(index),
                  child: Text('Item $index'),
                ),
              );
            },
          ),
        ),
      );

      // Scroll far away
      await tester.drag(find.text('Item 0'), const Offset(0, -1000));
      await tester.pump();

      // Verify item 0 WAS disposed
      expect(disposeCalls, contains(0));
    });
  });
}
