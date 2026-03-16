import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

class ConcreteAsyncComputed extends LxAsyncComputed<int> {
  ConcreteAsyncComputed() : super(() async => 0);
  @override LxStatus<int> get value => LxSuccess(0);
  @override Stream<LxStatus<int>> get stream => const Stream.empty();
  @override dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('LxAsyncComputed constructor', () {
    final computed = ConcreteAsyncComputed();
    expect(computed, isA<LxAsyncComputed>());
  });
}
