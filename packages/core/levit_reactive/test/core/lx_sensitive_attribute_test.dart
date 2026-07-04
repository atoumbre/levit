import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('isSensitive getter and setter', () {
    final v = 0.lx;
    expect(v.isSensitive, false);
    v.isSensitive = true;
    expect(v.isSensitive, true);
    v.isSensitive = true;
    expect(v.isSensitive, true);
  });
}
