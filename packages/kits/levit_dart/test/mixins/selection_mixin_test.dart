import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class TestMultiSelectController extends LevitController
    with LevitSelectionMixin<String> {}

class TestSingleSelectController extends LevitController
    with LevitSelectionMixin<String> {
  @override
  bool get allowMultiSelect => false;
}

void main() {
  group('LevitSelectionMixin', () {
    test('Multi-Select works correctly', () {
      final controller = TestMultiSelectController();
      controller.onInit();

      controller.select('A');
      controller.select('B');

      expect(controller.selectedItems, containsAll(['A', 'B']));
      expect(controller.selectionCount, 2);

      controller.toggle('A');
      expect(controller.selectedItems, contains('B'));
      expect(controller.selectedItems, isNot(contains('A')));

      controller.clearSelection();
      expect(controller.selectedItems, isEmpty);
    });

    test('Single-Select works correctly', () {
      final controller = TestSingleSelectController();
      controller.onInit();

      controller.select('A');
      expect(controller.selectedItems, contains('A'));

      controller.select('B');
      expect(controller.selectedItems, contains('B'));
      expect(controller.selectedItems, isNot(contains('A'))); // A was removed
      expect(controller.selectionCount, 1);
    });

    test('selectAll works correctly', () {
      final controller = TestMultiSelectController();
      controller.onInit();

      controller.selectAll(['A', 'B', 'C']);
      expect(controller.selectedItems.length, 3);
    });

    test('selectAll respects single mode', () {
      final controller = TestSingleSelectController();
      controller.onInit();

      controller.selectAll(['A', 'B', 'C']);
      expect(controller.selectedItems.length, 1);
      expect(controller.selectedItems, contains('C')); // Takes last one
    });
  });
}
