import 'dart:async';
import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

class TestRejectMiddleware extends LevitReactiveMiddleware {
  @override
  LxOnSet? get onSet => (next, reactive, change) => (value) {};
  @override
  LxOnBatch? get onBatch =>
      (next, change) => () => throw StateError('Batch rejected');
}

class TestSimpleMiddleware extends LevitReactiveMiddleware {
  final List<LevitReactiveChange> changes = [];
  @override
  LxOnSet? get onSet => (next, reactive, change) => (value) {
        next(value);
        changes.add(change);
      };
}

void main() {
  test('Lx bind handles stream errors', () async {
    final controller = StreamController<int>();
    final count = 0.lx;
    count.bind(controller.stream);

    final events = <dynamic>[];
    final sub = count.stream
        .listen((v) => events.add(v), onError: (e) => events.add('Error: $e'));

    controller.addError('Stream Error');
    controller.add(5);

    await Future.delayed(Duration.zero);
    await Future.delayed(Duration(milliseconds: 10));

    expect(events, contains(5));
    expect(count.value, equals(5));

    await sub.cancel();
    await controller.close();
  });
}
