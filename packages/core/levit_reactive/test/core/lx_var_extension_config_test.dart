import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('lxVar extension with config', () {
    final v = 'test'.lxVar(named: 'my_var', isSensitive: true);
    expect(v.value, 'test');
    expect(v.name, 'my_var');
    expect(v.isSensitive, true);
  });
}
