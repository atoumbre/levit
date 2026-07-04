import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('LxComputed handles error during read with active proxy', () {
    final consumer = LxComputed(() {
      try {
        throw 'Error!';
      } catch (_) {
        return LxError('Caught!', null);
      }
    });
    expect(consumer.value, isA<LxError>());
    expect(consumer.value.error, 'Caught!');
  });
}
