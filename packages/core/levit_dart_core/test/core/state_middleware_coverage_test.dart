import 'package:levit_dart_core/levit_dart_core.dart';
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

    test('token-based state middleware registration is unique per token', () {
      final calls = <String>[];
      final first = _TestMiddleware(
        onSetCallback: (next, reactive, change) {
          calls.add('first');
          return next;
        },
      );
      final second = _TestMiddleware(
        onSetCallback: (next, reactive, change) {
          calls.add('second');
          return next;
        },
      );

      Levit.addStateMiddleware(first, token: 'state_mw');
      Levit.addStateMiddleware(second, token: 'state_mw');

      final counter = 0.lx;
      counter.value = 1;

      expect(calls, ['second']);
      expect(Lx.containsMiddleware(first), isFalse);
      expect(Lx.containsMiddleware(second), isTrue);
      expect(Levit.removeStateMiddlewareByToken('state_mw'), isTrue);
    });
  });
}

class _TestMiddleware implements LevitReactiveMiddleware {
  final LxOnSet? onSetCallback;

  _TestMiddleware({this.onSetCallback});

  @override
  LxOnSet? get onSet => onSetCallback;

  @override
  LxOnBatch? get onBatch => null;

  @override
  LxOnDispose? get onDispose => null;

  @override
  void Function(LxReactive)? get onInit => null;

  @override
  void Function(LxReactive, List<LxReactive>)? get onGraphChange => null;
  @override
  void Function(LxReactive, LxListenerContext?)? get startedListening => null;
  @override
  void Function(LxReactive, LxListenerContext?)? get stoppedListening => null;

  @override
  void Function(Object, StackTrace?, LxReactive?)? get onReactiveError => null;
}
