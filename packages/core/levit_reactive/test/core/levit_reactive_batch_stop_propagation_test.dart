import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('LevitReactiveBatch stopPropagation', () {
    final composite = LevitReactiveBatch([]);

    expect(composite.isPropagationStopped, isFalse);

    composite.stopPropagation();
    expect(composite.isPropagationStopped, isTrue);
  });
}
