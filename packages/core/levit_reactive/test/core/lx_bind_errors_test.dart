import 'dart:async';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('bind handles errors', () async {
    final controller = StreamController<int>();
    final count = 0.lx;
    count.bind(controller.stream);

    final future = expectLater(count.stream, emitsError('Stream Error'));
    controller.addError('Stream Error');

    await future;
    await controller.close();
  });
}
