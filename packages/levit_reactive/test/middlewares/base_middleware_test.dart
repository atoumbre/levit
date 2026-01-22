import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

class BaseMiddleware extends LevitReactiveMiddleware {
  // Uses default implementations
}

void main() {
  group('LevitReactiveMiddleware Base', () {
    test('default onSet returns null', () {
      final mw = BaseMiddleware();
      expect(mw.onSet, isNull);
    });

    test('default onBatch returns null', () {
      final mw = BaseMiddleware();
      expect(mw.onBatch, isNull);
    });

    test('default onDispose returns null', () {
      final mw = BaseMiddleware();
      expect(mw.onDispose, isNull);
    });

    test('default onInit returns null', () {
      final mw = BaseMiddleware();
      expect(mw.onInit, isNull);
    });

    test('default onGraphChange returns null', () {
      final mw = BaseMiddleware();
      expect(mw.onGraphChange, isNull);
    });
  });
}
