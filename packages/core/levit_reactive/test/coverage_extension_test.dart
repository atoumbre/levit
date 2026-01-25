import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  group('levit_reactive Coverage Extension', () {
    test('LxComputed staticDeps success', () {
      final v1 = LxVar(1);
      final c1 = LxComputed(() => v1.value + 10, staticDeps: true);
      expect(c1.value, 11);
      // Change v1 to trigger recompute with static graph
      v1.value = 2;
      expect(c1.value, 12);
    });

    test('LxComputed staticDeps async success', () async {
      final v1 = LxVar(1);
      final c1 = LxAsyncComputed(() async => v1.value + 20, staticDeps: true);
      expect((await c1.stream.firstWhere((s) => s.hasValue)).valueOrNull, 21);
      v1.value = 2;
      expect((await c1.stream.firstWhere((s) => s.hasValue)).valueOrNull, 22);
    });

    test('LxComputed staticDeps sync error', () {
      bool fail = true;
      expect(
          () => LxComputed(() {
                if (fail) throw 'sync_error';
              }, staticDeps: true),
          throwsA('sync_error'));
    });

    test('LxAsyncComputed staticDeps async error', () async {
      bool fail = true;
      final c1 = LxAsyncComputed(() async {
        if (fail) throw 'async_error';
        return 1;
      }, staticDeps: true);

      final terminalStatus =
          await c1.stream.firstWhere((s) => s is LxSuccess || s is LxError);
      expect(terminalStatus.hasError, true);
      expect((terminalStatus as LxError).error, 'async_error');

      fail = false;
    });

    test('LevitReactiveMiddleware error hook', () {
      String? caught;
      final mw = _ErrorMiddleware((e, s, r) {
        caught = e.toString();
      });

      Lx.addMiddleware(mw);

      final v1 = LxVar(1);
      v1.addListener(() {
        throw 'listener_error';
      });

      v1.value =
          2; // Should hit catch block in core.dart and applyOnReactiveError
      expect(caught, 'listener_error');

      Lx.removeMiddleware(mw);
    });

    test('Lx runWithOwner and listenerContext', () {
      String? currentOwner;
      Lx.runWithOwner('test-owner', () {
        final context = Lx.listenerContext;
        if (context != null && context.data is Map) {
          currentOwner = (context.data as Map)['ownerId'] as String?;
        }
      });
      expect(currentOwner, 'test-owner');
      expect(Lx.listenerContext, isNull);
    });
  });
}

class _ErrorMiddleware extends LevitReactiveMiddleware {
  final void Function(Object e, StackTrace? s, LxReactive? r) onError;
  _ErrorMiddleware(this.onError);

  @override
  void Function(Object e, StackTrace? s, LxReactive? r)? get onReactiveError =>
      onError;
}
