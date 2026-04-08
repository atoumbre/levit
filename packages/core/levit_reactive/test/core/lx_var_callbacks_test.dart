import 'dart:async';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('onListen and onCancel callbacks', () async {
    bool listened = false;
    bool cancelled = false;

    final count = LxVar(0,
        onListen: () => listened = true, onCancel: () => cancelled = true);
    final sub = count.stream.listen((_) {});
    await Future.delayed(Duration.zero);
    expect(listened, isTrue);

    await sub.cancel();
    await Future.delayed(Duration.zero);
    expect(cancelled, isTrue);
  });
}
