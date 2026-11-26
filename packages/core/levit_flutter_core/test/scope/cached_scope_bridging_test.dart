import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  group('Cached scope bridging on reactive widgets', () {
    testWidgets('LBuilder and LWatch track scope replacement and reparenting', (
      tester,
    ) async {
      final tick = 0.lx;
      final status = LxVar<LxStatus<int>>(const LxSuccess(1));
      final scopeKey = GlobalKey();
      final watchKey = GlobalKey();
      final builderKey = GlobalKey();
      final selectorKey = GlobalKey();
      final statusKey = GlobalKey();

      addTearDown(() async {
        await tick.close();
        await status.close();
      });

      Widget buildTree({required String generation, required bool moveChild}) {
        final reactiveRow = Row(
          children: [
            LWatch(
              key: watchKey,
              () => Text('W:${Levit.find<String>()}:${tick()}'),
            ),
            LBuilder(
              tick,
              key: builderKey,
              (v) => Text('B:${Levit.find<String>()}:$v'),
            ),
            LSelectorBuilder(
              () => tick() * 2,
              key: selectorKey,
              (v) => Text('S:${Levit.find<String>()}:$v'),
            ),
            LStatusBuilder(
              status,
              key: statusKey,
              onSuccess: (v) => Text('ST:${Levit.find<String>()}:$v'),
            ),
          ],
        );

        return Directionality(
          textDirection: TextDirection.ltr,
          child: LScope(
            key: scopeKey,
            args: [generation],
            configure: (scope) {
              scope.put<String>(() => generation);
            },
            child: moveChild ? SizedBox(child: reactiveRow) : reactiveRow,
          ),
        );
      }

      await tester.pumpWidget(buildTree(generation: 'gen1', moveChild: false));
      expect(find.text('W:gen1:0'), findsOneWidget);
      expect(find.text('B:gen1:0'), findsOneWidget);
      expect(find.text('S:gen1:0'), findsOneWidget);
      expect(find.text('ST:gen1:1'), findsOneWidget);

      // Update reactive state without changing scope (cached fast path).
      tick.value = 1;
      await tester.pump();
      expect(find.text('W:gen1:1'), findsOneWidget);
      expect(find.text('B:gen1:1'), findsOneWidget);
      expect(find.text('S:gen1:2'), findsOneWidget);

      // Replace ancestor scope; cached scope must invalidate and bridge gen2.
      await tester.pumpWidget(buildTree(generation: 'gen2', moveChild: false));
      await tester.pump();
      expect(find.text('W:gen2:1'), findsOneWidget);
      expect(find.text('B:gen2:1'), findsOneWidget);
      expect(find.text('S:gen2:2'), findsOneWidget);
      expect(find.text('ST:gen2:1'), findsOneWidget);

      // Reparent keyed elements via activate(); scope resolution remains valid.
      await tester.pumpWidget(buildTree(generation: 'gen2', moveChild: true));
      tick.value = 2;
      status.value = const LxSuccess(9);
      await tester.pump();
      expect(find.text('W:gen2:2'), findsOneWidget);
      expect(find.text('B:gen2:2'), findsOneWidget);
      expect(find.text('S:gen2:4'), findsOneWidget);
      expect(find.text('ST:gen2:9'), findsOneWidget);
    });
  });
}
