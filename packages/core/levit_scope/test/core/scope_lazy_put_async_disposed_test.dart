import 'dart:async';
import 'package:test/test.dart';
import 'package:levit_scope/levit_scope.dart';

class _Disposable extends LevitScopeDisposable {
  final void Function() _onClose;
  _Disposable(this._onClose);
  @override
  void onClose() => _onClose();
}

void main() {
  test('lazyPutAsync disposed during init throws and closes instance',
      () async {
    final scope = LevitScope.root('root3');
    int closed = 0;
    final completer = Completer<void>();

    scope.lazyPutAsync<_Disposable>(() async {
      await completer.future;
      return _Disposable(() => closed++);
    });

    final future = scope.findAsync<_Disposable>();
    final deleted = scope.delete<_Disposable>();
    expect(deleted, isTrue);

    completer.complete();
    await expectLater(future, throwsA(isA<StateError>()));
    expect(closed, 1);
  });
}
