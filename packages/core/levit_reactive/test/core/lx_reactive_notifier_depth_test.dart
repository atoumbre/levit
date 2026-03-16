import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('LevitReactiveNotifier graphDepth getter and setter', () {
    final reactive = 0.lx;
    reactive.graphDepth = 10;
    expect(reactive.graphDepth, 10);
  });
}
