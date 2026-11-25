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
  test(
    'lazyPutAsync disposed during init throws and closes instance',
    () async {
      final scope = LevitScope.root('root3');
      int closed = 0;
      final completer = Completer<void>();

      scope.lazyPutAsync<_Disposable>(() async {
        await completer.future;
        return _Disposable(() => closed++);
      });

      final future = scope.findAsync<_Disposable>();
      final rejected = expectLater(future, throwsA(isA<StateError>()));
      final deletion = scope.delete<_Disposable>();
      completer.complete();
      await rejected;
      expect(await deletion, isTrue);
      expect(closed, 1);
    },
  );
}
