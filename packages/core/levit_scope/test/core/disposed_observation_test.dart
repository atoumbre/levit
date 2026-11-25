import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';

class _Failing extends LevitScopeDisposable {
  @override
  void onClose() => throw StateError('cleanup');
}

class _Callback extends LevitScopeDisposable {
  _Callback(this.close);
  final void Function() close;
  @override
  void onClose() => close();
}

void main() {
  test(
    'disposal is published before synchronous cleanup can reenter it',
    () async {
      final scope = LevitScope.root();
      late Future<void> reentered;
      var closes = 0;
      scope.put(
        () => _Callback(() {
          closes++;
          reentered = scope.dispose();
        }),
      );
      final closing = scope.dispose();
      expect(reentered, same(closing));
      await closing;
      expect(closes, 1);
    },
  );
  test(
    'first terminal observation after unobserved success is complete and stable',
    () async {
      final scope = LevitScope.root();
      await scope.dispose();
      final done = scope.disposed;
      expect(scope.disposed, same(done));
      await done;
    },
  );
  test(
    'first terminal observation after failed cleanup still completes',
    () async {
      final scope = LevitScope.root()..put(_Failing.new);
      await expectLater(
        scope.dispose(),
        throwsA(isA<LevitDisposalException>()),
      );
      await scope.disposed;
      expect(scope.isDisposed, isTrue);
      await expectLater(
        scope.dispose(),
        throwsA(isA<LevitDisposalException>()),
      );
    },
  );
}
