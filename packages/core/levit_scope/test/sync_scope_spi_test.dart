import 'package:levit_scope/levit_scope.dart';
import 'package:levit_scope/spi.dart';
import 'package:test/test.dart';

void main() {
  group('LsSpi.enterSyncScope and exitSyncScope', () {
    test('binds and restores nested synchronous scopes cleanly', () async {
      final outer = LevitScope.root('outer');
      final inner = outer.createScope('inner');
      outer.put(() => 'outer-value');
      inner.put(() => 'inner-value');

      final prevOuter = LsSpi.enterSyncScope(outer);
      try {
        expect(identical(Ls.currentScope, outer), isTrue);
        expect(Ls.find<String>(), 'outer-value');

        final prevInner = LsSpi.enterSyncScope(inner);
        try {
          expect(identical(Ls.currentScope, inner), isTrue);
          expect(Ls.find<String>(), 'inner-value');
        } finally {
          LsSpi.exitSyncScope(prevInner);
        }

        expect(identical(Ls.currentScope, outer), isTrue);
        expect(Ls.find<String>(), 'outer-value');
      } finally {
        LsSpi.exitSyncScope(prevOuter);
      }

      expect(identical(Ls.currentScope, outer), isFalse);
      await outer.dispose();
    });
  });
}
