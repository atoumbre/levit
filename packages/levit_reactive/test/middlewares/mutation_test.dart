import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

class TestMutationMiddleware extends LevitReactiveMiddleware {
  int changeCount = 0;

  @override
  LxOnSet? get onSet => (next, reactive, change) {
        return (value) {
          next(value);
          changeCount++;
        };
      };
}

void main() {
  test('LxMap mutation triggers middleware', () {
    final map = LxMap<String, int>();
    final middleware = TestMutationMiddleware();
    Lx.addMiddleware(middleware);

    // Mutate map
    map['a'] = 1;

    Lx.removeMiddleware(middleware);

    expect(middleware.changeCount, equals(1),
        reason: 'Middleware should be notified of map mutation');
  });

  test('LxInt mutation triggers middleware', () {
    final i = LxInt(0);
    final middleware = TestMutationMiddleware();
    Lx.addMiddleware(middleware);

    // Mutate int
    i.value = 1;

    Lx.removeMiddleware(middleware);

    expect(middleware.changeCount, equals(1));
  });
}
