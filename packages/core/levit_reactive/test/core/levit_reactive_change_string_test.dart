import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('LevitReactiveChange toString', () {
    final change = LevitReactiveChange(timestamp: DateTime.now(), valueType: int, oldValue: 1, newValue: 2);
    expect(change.toString(), contains('int: 1 → 2'));
  });
}
