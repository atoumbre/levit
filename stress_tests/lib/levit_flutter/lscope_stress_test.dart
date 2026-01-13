import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

class _TestController extends LevitController {
  final int id;
  _TestController(this.id);
}

void main() {
  setUp(() {
    Levit.reset(force: true);
  });

  group('Stress Test: LScope', () {
    testWidgets('Deep Tree - 500 nested LScope widgets', (tester) async {
      print(
          '[Description] Tests resolution through deeply nested LScope widgets.');
      const depth = 500;

      Widget buildNested(int level) {
        if (level >= depth) {
          return Builder(builder: (context) {
            final sw = Stopwatch()..start();
            final ctrl = Levit.find<_TestController>(tag: 'root');
            sw.stop();
            print(
                'Resolved deep scope through $depth layers in ${sw.elapsedMilliseconds}ms');
            return Text('ID: ${ctrl.id}');
          });
        }
        return LScope<int>(
          init: () => level,
          child: buildNested(level + 1),
        );
      }

      Levit.put<_TestController>(() => _TestController(42), tag: 'root');

      await tester.pumpWidget(MaterialApp(home: buildNested(0)));

      expect(find.text('ID: 42'), findsOneWidget);
    });

    testWidgets('Churn - 200 mount/unmount LScope cycles', (tester) async {
      print('[Description] Tests LScope mount/unmount performance.');
      const cycles = 200;

      final sw = Stopwatch()..start();
      for (var i = 0; i < cycles; i++) {
        await tester.pumpWidget(MaterialApp(
          home: LScope<_TestController>(
            init: () => _TestController(i),
            child: const Text('Scoped'),
          ),
        ));
        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      }
      sw.stop();

      final opsPerMs = cycles / sw.elapsedMilliseconds;
      print(
          'LScope Churn: $cycles mount/unmount cycles in ${sw.elapsedMilliseconds}ms (${opsPerMs.toStringAsFixed(1)} ops/ms)');
    });
  });
}
