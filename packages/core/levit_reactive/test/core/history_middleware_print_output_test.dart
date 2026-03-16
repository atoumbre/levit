import 'dart:async';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('printHistory output', () {
    final logs = <String>[];
    final history = LevitReactiveHistoryMiddleware();

    runZoned(() {
      Lx.addMiddleware(history);
      final count = 0.lx;
      count.value = 1;
      history.undo();
      history.printHistory();
    }, zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => logs.add(line),
    ));

    expect(logs, contains('--- Undo Stack ---'));
    expect(logs, contains('--- Redo Stack ---'));
  });
}
