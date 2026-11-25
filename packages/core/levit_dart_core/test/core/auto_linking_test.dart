import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';
import 'dart:async';
import 'package:levit_dart_core/spi.dart';

void main() {
  setUp(() {
    Levit.enableAutoLinking();
  });

  tearDown(() async {
    await Levit.reset(force: true);
    Levit.disableAutoLinking();
  });

  group('Reactive ownership during controller initialization', () {
    test('captures reactives in controller and auto-disposes', () async {
      final controller = TestController();
      Levit.put(() => controller);

      // Verify reactives were created and captured
      expect(controller.count.value, 0);
      expect(controller.doubled.value, 0);

      // Update values
      controller.count.value = 5;
      expect(controller.doubled.value, 10);

      // Delete controller - should auto-dispose reactives
      await Levit.delete<TestController>(force: true);
    });

    test(
      'separately registered controllers own their initialized values',
      () async {
        final parentController = ParentController();
        final childController = ChildController();

        Levit.put(() => parentController);
        Levit.put(() => childController);

        // Both controllers should have their reactives
        expect(parentController.parentValue.value, 0);
        expect(childController.childValue.value, 0);

        // Cleanup
        await Levit.delete<ParentController>(force: true);
        await Levit.delete<ChildController>(force: true);
      },
    );

    test('capture list length operations work correctly', () async {
      final controller = MultiReactiveController();
      Levit.put(() => controller);

      // Controller creates multiple reactives
      // This exercises the length getter
      expect(controller.values.length, 5);

      // Cleanup
      await Levit.delete<MultiReactiveController>(force: true);
    });

    test('capture list index operations work correctly', () async {
      final controller = IndexTestController();
      Levit.put(() => controller);

      // Access values by index (exercises operator[])
      expect(controller.getValueAt(0), 0);
      expect(controller.getValueAt(1), 1);
      expect(controller.getValueAt(2), 2);

      // Cleanup
      await Levit.delete<IndexTestController>(force: true);
    });

    test(
      'captured reactives support length, indexing, replacement, and append',
      () async {
        final controller = InterceptController();
        Levit.put(() => controller);

        final list = controller.captureList;
        expect(list, isNotNull);
        if (list != null) {
          // Exercise length
          expect(list.length, isPositive);
          list.length = list.length; // setter

          // Exercise operator[]
          final first = list[0];
          expect(first, isNotNull);

          // Exercise operator[]=
          list[0] = first;

          // Exercise add (already covered, but for completeness)
          final r = 0.lx;
          list.add(r);
          await r.close();
        }

        await Levit.delete<InterceptController>(force: true);
      },
    );

    test(
      'a nested capture isolates its allocations and restores the caller',
      () async {
        late LxInt first, nested, last;
        LevitAutoLinkSpi.runCaptured(() {
          final outer =
              Zone.current[LevitAutoLinkSpi.captureKey] as List<LxReactive>;
          first = 1.lx;
          LevitAutoLinkSpi.runCaptured(() {
            nested = 2.lx;
            expect(Zone.current[LevitAutoLinkSpi.captureKey], [nested]);
          }, 'inner');
          last = 3.lx;
          expect(outer, [first, last]);
        }, 'outer');
        await Future.wait([first.close(), nested.close(), last.close()]);
      },
    );
  });
}

class InterceptController extends LevitController {
  List<LxReactive>? captureList;
  @override
  void onInit() {
    captureList =
        Zone.current[LevitAutoLinkSpi.captureKey] as List<LxReactive>?;
    0.lx; // Create a reactive to populate the list
    super.onInit();
  }
}

class TestController extends LevitController {
  late final LxInt count;
  late final LxComputed<int> doubled;

  @override
  void onInit() {
    super.onInit();
    count = 0.lx.named('count');
    doubled = (() => (count.value) * 2).lx.named('doubled');
  }
}

class ParentController extends LevitController {
  late final LxInt parentValue;

  @override
  void onInit() {
    super.onInit();
    parentValue = 0.lx.named('parent');
  }
}

class ChildController extends LevitController {
  late final LxInt childValue;

  @override
  void onInit() {
    super.onInit();
    childValue = 0.lx.named('child');
  }
}

class MultiReactiveController extends LevitController {
  late final List<LxInt> values;

  @override
  void onInit() {
    super.onInit();
    values = List.generate(5, (i) => i.lx.named('value_$i'));
  }
}

class IndexTestController extends LevitController {
  late final List<LxInt> values;

  @override
  void onInit() {
    super.onInit();
    values = List.generate(3, (i) => i.lx.named('indexed_$i'));
  }

  int getValueAt(int index) => values[index].value;
}
