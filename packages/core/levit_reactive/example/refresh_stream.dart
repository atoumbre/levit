// Run with: dart run example/refresh_stream.dart
import 'dart:async';
import 'package:levit_reactive/levit_reactive.dart';

Future<void> main() async {
  var generation = 0;
  final updates = LxStream<int>.defer(
    () => Stream.value(++generation),
    completionPolicy: LxStreamCompletionPolicy.retain,
  );
  final first = Completer<void>();
  final second = Completer<void>();
  final subscription = updates.stream.listen((status) {
    if (status is LxSuccess<int>) {
      print(status.value);
      if (status.value == 1 && !first.isCompleted) first.complete();
      if (status.value == 2 && !second.isCompleted) second.complete();
    }
  });
  await first.future;
  updates.restartDeferred(() => Stream.value(++generation));
  await second.future;
  await subscription.cancel();
  await updates.close();
}
