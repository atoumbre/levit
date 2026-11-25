import 'dart:async';

import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';

class _AsyncResource implements LevitDisposable {
  _AsyncResource(this.gate);

  final Completer<void> gate;
  bool disposed = false;

  @override
  Future<void> dispose() async {
    await gate.future;
    disposed = true;
  }
}

void main() {
  group('Re-entrant put cleanup', () {
    test(
      'disposes created resource and throws when scope closes during put',
      () async {
        final scope = LevitScope.root('disposed_during_put');
        final gate = Completer<void>();
        late _AsyncResource created;

        expect(
          () => scope.put<_AsyncResource>(() {
            created = _AsyncResource(gate);
            scope.requestCancel();
            return created;
          }),
          throwsStateError,
        );

        gate.complete();
        await Future<void>.delayed(Duration.zero);
        expect(created.disposed, isTrue);
      },
    );

    test(
      'disposes and tracks created resource when key is registered during put',
      () async {
        final scope = LevitScope.root('duplicate_during_put');
        final existingGate = Completer<void>()..complete();
        final createdGate = Completer<void>();
        late _AsyncResource created;

        expect(
          () => scope.put<_AsyncResource>(() {
            scope.put<_AsyncResource>(() => _AsyncResource(existingGate));
            created = _AsyncResource(createdGate);
            return created;
          }),
          throwsStateError,
        );

        var settled = false;
        final waiting = scope.waitForInitialization().then((_) {
          settled = true;
        });
        await Future<void>.delayed(Duration.zero);
        expect(settled, isFalse);

        createdGate.complete();
        await waiting;
        expect(created.disposed, isTrue);
        await scope.dispose();
      },
    );
  });
}
