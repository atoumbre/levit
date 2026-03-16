import 'dart:async';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('LxAsyncComputed staticDeps sync error on first run (Active)', () async {
    final a = 1.lx;
    final c = LxAsyncComputed<int>(() async {
      if (a.value == 1) throw 'SyncError';
      return a.value;
    }, staticDeps: true);

    c.addListener(() {});
    await Future.delayed(Duration(milliseconds: 10));

    expect(c.value, isA<LxError>());
    a.value = 10;
    await Future.delayed(Duration(milliseconds: 10));
  });
}
