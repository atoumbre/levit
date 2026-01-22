import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('LxStatus Extension Coverage', () {
    test('LxVarExtensions.listen creates LxWatch', () {
      final rx = 0.lx;
      var callCount = 0;

      final watch = rx.listen((value) {
        callCount++;
      });

      expect(watch, isA<LxWatch<int>>());

      rx.value = 1;
      expect(callCount, 1);

      watch.close();
    });

    test('LxStatusReactiveExtensions.listen with callbacks', () {
      final future = Future.value(42).lx;
      var successCalled = false;
      var waitingCalled = false;

      final watch = future.listen(
        (value) {
          successCalled = true;
          expect(value, 42);
        },
        onWaiting: () {
          waitingCalled = true;
        },
        onError: (error) {
          fail('Should not error');
        },
      );

      expect(watch, isA<LxWatch<LxStatus<int>>>());
      expect(waitingCalled, isFalse);

      // Wait for future to complete
      return Future.delayed(Duration(milliseconds: 50)).then((_) {
        expect(successCalled, isTrue);
        watch.close();
      });
    });

    test('LxStatusReactiveExtensions.listen with error callback', () async {
      final future = Future<int>.error('Test error').lx;
      var errorCalled = false;

      final watch = future.listen(
        (value) {
          fail('Should not succeed');
        },
        onError: (error) {
          errorCalled = true;
          expect(error, 'Test error');
        },
      );

      await Future.delayed(Duration(milliseconds: 50));
      expect(errorCalled, isTrue);
      watch.close();
    });
  });
}
