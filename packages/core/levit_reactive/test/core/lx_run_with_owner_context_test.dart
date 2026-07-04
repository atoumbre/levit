import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('Lx runWithOwner and listenerContext', () {
    String? currentOwner;
    Lx.runWithOwner('test-owner', () {
      final context = Lx.listenerContext;
      if (context != null && context.data is Map) {
        currentOwner = (context.data as Map)['ownerId'] as String?;
      }
    });
    expect(currentOwner, 'test-owner');
  });
}
