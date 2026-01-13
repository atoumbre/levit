import 'dart:async';
import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('Design Consistency', () {
    group('LxFuture', () {
      test('computedValue returns value on success', () async {
        final f = LxFuture(Future.value(42));
        await Future.delayed(Duration(milliseconds: 10));
        expect(f.computedValue, equals(42));
      });

      test('computedValue throws on error', () async {
        final f = LxFuture(Future.error('failure'));
        await Future.delayed(Duration(milliseconds: 10));
        expect(() => f.computedValue, throwsA(equals('failure')));
      });

      test('computedValue throws when waiting', () {
        final f = LxFuture(Completer<int>().future);
        expect(() => f.computedValue, throwsStateError);
      });

      test('hasListener tracks subscriptions', () {
        final f = LxFuture(Future.value(1));
        expect(f.hasListener, isFalse);
        final sub = f.stream.listen((_) {});
        expect(f.hasListener, isTrue);
        sub.cancel();
        expect(f.hasListener, isFalse);
      });
    });

    group('LxStream', () {
      test('computedValue returns value on success', () async {
        final s = LxStream(Stream.value(42));
        s.addListener(() {}); // Activate lazy stream
        await Future.delayed(Duration(milliseconds: 10));
        expect(s.computedValue, equals(42));
      });

      test('computedValue throws on error', () async {
        final s = LxStream(Stream.error('failure'));
        s.addListener(() {}); // Activate lazy stream
        await Future.delayed(Duration(milliseconds: 10));
        expect(() => s.computedValue, throwsA(equals('failure')));
      });

      test('computedValue throws when waiting', () {
        final f = LxStream(Stream
            .empty()); // starts in LxWaiting since no initial and lazy activation not hit yet
        // Wait, LxStream starts in LxWaiting() if no initial value provided.
        expect(() => f.computedValue, throwsStateError);
      });

      test('hasListener tracks subscriptions', () {
        final s = LxStream(Stream.value(1));
        expect(s.hasListener, isFalse);
        final sub = s.stream.listen((_) {});
        // Note: s.stream returns _statusLx.stream.
        // _statusLx is an Lx. When we listen to it, its _controller gets a listener.
        expect(s.hasListener, isTrue);
        sub.cancel();
        expect(s.hasListener, isFalse);
      });
    });

    group('LxComputed.async', () {
      test('supports initial value', () async {
        final c = LxComputed.async(
          () async => 42,
          initial: 10,
        );

        expect(c.status, isA<LxSuccess<int>>());
        expect(c.computedValue, equals(10));
        expect(c.isSuccess, isTrue);

        // After recomputation it should update
        c.addListener(() {}); // Activate
        await Future.delayed(Duration(milliseconds: 10));
        expect(c.computedValue, equals(42));
      });

      test('memoAsync also supports initial value', () async {
        final c = LxComputed.async(
          () async => 42,
          initial: 10,
        );
        expect(c.computedValue, equals(10));
      });
    });

    group('Lx.bind', () {
      test('activates immediately if hasListener is true', () async {
        final source = 0.lx;
        final controller = StreamController<int>();

        // 1. Add manual listener first
        var listenerCalled = 0;
        source.addListener(() => listenerCalled++);
        expect(source.hasListener, isTrue);

        // 2. Bind to stream
        source.bind(controller.stream);

        // 3. Emit value - should reach the manual listener because binding is active
        controller.add(42);
        await Future.delayed(Duration.zero);

        expect(source.value, equals(42));
        expect(listenerCalled, equals(1));

        await controller.close();
      });
    });
  });
}
