import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

void main() {
  group('Levit.addStateMiddleware / removeStateMiddleware coverage', () {
    tearDown(() {
      Lx.clearMiddlewares();
    });

    test('addStateMiddleware registers middleware with Lx', () {
      final middleware = _TestMiddleware();

      Levit.addStateMiddleware(middleware);

      expect(Lx.containsMiddleware(middleware), isTrue);
    });

    test('removeStateMiddleware un-registers middleware from Lx', () {
      final middleware = _TestMiddleware();

      Levit.addStateMiddleware(middleware);
      expect(Lx.containsMiddleware(middleware), isTrue);

      Levit.removeStateMiddleware(middleware);
      expect(Lx.containsMiddleware(middleware), isFalse);
    });

    test('state middleware receives state changes', () {
      var setCalled = false;
      final middleware = _TestMiddleware(
        onSetCallback: (next, reactive, change) {
          setCalled = true;
          return next;
        },
      );

      Levit.addStateMiddleware(middleware);

      final counter = 0.lx;
      counter.value = 1;

      expect(setCalled, isTrue);

      Levit.removeStateMiddleware(middleware);
    });
  });
}

class _TestMiddleware extends LevitMiddleware {
  final LxOnSet? onSetCallback;

  _TestMiddleware({this.onSetCallback});

  @override
  LxOnSet? get onSet => onSetCallback;
}
