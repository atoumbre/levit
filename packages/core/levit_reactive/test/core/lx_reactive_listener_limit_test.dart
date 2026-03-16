import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('LxReactive 3+ listeners', () {
    final v = 0.lx;
    v.addListener(() {});
    v.addListener(() {});
    v.addListener(() {});
  });
}
