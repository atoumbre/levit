import 'package:test/test.dart';
import 'package:levit_reactive/spi.dart';

void main() {
  test('Lx runWithOwner and listenerContext', () {
    String? currentOwner;
    LxSpi.runWithOwner('test-owner', () {
      final context = LxSpi.listenerContext;
      if (context != null && context.data is Map) {
        currentOwner = (context.data as Map)['ownerId'] as String?;
      }
    });
    expect(currentOwner, 'test-owner');
  });
}
