import 'dart:async';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  group('LxFuture Refined Tests', () {
    test('future transformations emit the resolved value', () async {
      final future = Future.value(42).lx;
      future.addListener(() {}); // Activate immediately

      final transformed = future.transform(
        (s) => s.map((status) => status.valueOrNull),
      );
      transformed.addListener(() {}); // Keep alive

      await Future.delayed(const Duration(milliseconds: 30));
      expect(transformed.value.valueOrNull, 42);
    });
  });
}
