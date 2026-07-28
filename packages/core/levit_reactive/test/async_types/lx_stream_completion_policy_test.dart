import 'dart:async';

import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('close remains the completion default', () async {
    final stream = LxStream<int>(Stream<int>.value(1));
    final values = <LxStatus<int>>[];
    void listener() => values.add(stream.status);
    stream.addListener(listener);

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(values.whereType<LxSuccess<int>>().single.value, 1);
    expect(stream.isDisposed, isTrue);
  });

  test('retain preserves the final value and permits explicit restart',
      () async {
    final first = StreamController<int>();
    final second = StreamController<int>();
    final stream = LxStream<int>(
      first.stream,
      completionPolicy: LxStreamCompletionPolicy.retain,
    );
    final statuses = <LxStatus<int>>[];
    void listener() => statuses.add(stream.status);
    stream.addListener(listener);

    first.add(1);
    await first.close();
    await Future<void>.delayed(Duration.zero);

    expect(stream.isDisposed, isFalse);
    expect(stream.status, const LxSuccess<int>(1));

    stream.restart(second.stream);
    second.add(2);
    await Future<void>.delayed(Duration.zero);

    expect(stream.status, const LxSuccess<int>(2));
    expect(statuses.whereType<LxSuccess<int>>().map((s) => s.value), [1, 2]);

    await second.close();
    stream.close();
  });

  test('retain becomes idle when a source completes without a value', () async {
    final controller = StreamController<int>();
    final stream = LxStream<int>(
      controller.stream,
      completionPolicy: LxStreamCompletionPolicy.retain,
    );
    void listener() {}
    stream.addListener(listener);

    await controller.close();
    await Future<void>.delayed(Duration.zero);

    expect(stream.status, isA<LxIdle<int>>());
    expect(stream.isDisposed, isFalse);
    stream.close();
  });

  test('stale completion from an old binding cannot close a restarted stream',
      () async {
    final first = StreamController<int>();
    final second = StreamController<int>();
    final stream = LxStream<int>(
      first.stream,
      completionPolicy: LxStreamCompletionPolicy.retain,
    );
    void listener() {}
    stream.addListener(listener);

    stream.restart(second.stream);
    await first.close();
    second.add(3);
    await Future<void>.delayed(Duration.zero);

    expect(stream.status, const LxSuccess<int>(3));
    await second.close();
    stream.close();
  });
}
