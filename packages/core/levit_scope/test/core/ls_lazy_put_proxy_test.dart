import 'package:test/test.dart';
import 'package:levit_scope/levit_scope.dart';

void main() {
  test('Ls.lazyPut proxies', () async {
    Ls.reset(force: true);
    Ls.lazyPut(() => 10);
    expect(Ls.isRegistered<int>(), isTrue);
    expect(Ls.isInstantiated<int>(), isFalse);
    expect(Ls.find<int>(), 10);

    Ls.reset(force: true); // Add reset here

    Ls.lazyPutAsync(() async => 20);
    expect(Ls.isRegistered<int>(), isTrue);
    expect(await Ls.findAsync<int>(), 20);

    expect(await Ls.findOrNullAsync<double>(), isNull);
    Ls.reset(force: true);
  });
}
