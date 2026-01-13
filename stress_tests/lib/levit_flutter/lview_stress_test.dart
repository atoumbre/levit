import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

class _TestController extends LevitController {
  static int instanceCount = 0;
  static int disposeCount = 0;

  _TestController() {
    instanceCount++;
  }

  @override
  void onClose() {
    disposeCount++;
    super.onClose();
  }
}

class _TestView extends LView<_TestController> {
  const _TestView();

  @override
  _TestController? createController() => _TestController();

  @override
  Widget buildContent(BuildContext context, _TestController controller) {
    return const SizedBox.shrink();
  }
}

void main() {
  setUp(() {
    Levit.reset(force: true);
    _TestController.instanceCount = 0;
    _TestController.disposeCount = 0;
  });

  group('Stress Test: LView', () {
    testWidgets('Lifecycle - 100 mount/unmount cycles', (tester) async {
      print('[Description] Tests LView controller lifecycle under churn.');
      const cycles = 100;

      final sw = Stopwatch()..start();
      for (var i = 0; i < cycles; i++) {
        await tester.pumpWidget(const MaterialApp(home: _TestView()));
        Levit.reset(force: true); // Force cleanup between cycles
        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      }
      sw.stop();

      print(
          'LView Lifecycle: $cycles mount/unmount cycles in ${sw.elapsedMilliseconds}ms');
      print(
          'Controllers created: ${_TestController.instanceCount}, disposed: ${_TestController.disposeCount}');

      expect(_TestController.instanceCount, cycles);
      expect(_TestController.disposeCount, cycles);
    });

    testWidgets('Controller Access - 10k access calls', (tester) async {
      print('[Description] Measures controller access performance from LView.');
      Levit.put<_TestController>(() => _TestController(), tag: 'ctrl');

      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          final sw = Stopwatch()..start();
          for (var i = 0; i < 10000; i++) {
            Levit.find<_TestController>(tag: 'ctrl');
          }
          sw.stop();
          print(
              'Controller Access: 10k Levit.find calls in ${sw.elapsedMilliseconds}ms');
          return const SizedBox.shrink();
        }),
      ));
    });
  });
}
