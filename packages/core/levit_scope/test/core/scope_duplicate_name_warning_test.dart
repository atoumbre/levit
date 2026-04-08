import 'dart:async';
import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';

void main() {
  test('createScope prints warning if child shares ancestor name', () {
    final parent = LevitScope.root().createScope('SharedName');
    final logs = <String>[];
    runZoned(() {
      parent.createScope('SharedName');
    },
        zoneSpecification: ZoneSpecification(
          print: (self, parentZone, zone, line) => logs.add(line),
        ));
    expect(
        logs.any(
            (l) => l.contains('Child scope "SharedName" has the same name')),
        isTrue);
  });
}
