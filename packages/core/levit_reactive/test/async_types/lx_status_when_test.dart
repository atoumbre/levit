import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  group('LxStatus when and maybeWhen', () {
    test('dispatches all four states and falls back from idle to waiting', () {
      String describe(LxStatus<int> status, {bool includeIdle = true}) =>
          status.when(
            onSuccess: (value) => 'success:$value',
            onWaiting: () => 'waiting',
            onError: (error, stack) => 'error:$error:${stack != null}',
            onIdle: includeIdle ? () => 'idle' : null,
          );

      expect(describe(LxIdle<int>()), 'idle');
      expect(describe(LxIdle<int>(), includeIdle: false), 'waiting');
      expect(describe(LxWaiting<int>()), 'waiting');
      expect(describe(const LxSuccess<int>(42)), 'success:42');
      expect(
        describe(LxError<int>('boom', StackTrace.current)),
        'error:boom:true',
      );
      expect(describe(const LxError<int>('boom')), 'error:boom:false');
    });

    test('maybeWhen invokes matching branch or orElse', () {
      expect(
        const LxSuccess<int>(
          7,
        ).maybeWhen(onSuccess: (value) => value * 2, orElse: () => -1),
        14,
      );
      expect(
        LxWaiting<int>().maybeWhen(
          onSuccess: (value) => value * 2,
          orElse: () => -1,
        ),
        -1,
      );
      expect(
        LxIdle<int>().maybeWhen(onIdle: () => 'idle', orElse: () => 'other'),
        'idle',
      );
      expect(
        const LxError<int>('bad').maybeWhen(
          onError: (error, _) => 'caught:$error',
          orElse: () => 'other',
        ),
        'caught:bad',
      );
    });

    test(
      'LxReadable<LxStatus<T>> extension registers reactive dependencies',
      () {
        final status = LxVar<LxStatus<int>>(LxWaiting<int>());
        final summary = LxComputed(
          () => status.when(
            onSuccess: (value) => 'value:$value',
            onWaiting: () => 'loading',
            onError: (error, _) => 'err:$error',
            onIdle: () => 'idle',
          ),
        );
        final fallback = LxComputed(
          () => status.maybeWhen(
            onSuccess: (value) => 'ok:$value',
            orElse: () => 'pending',
          ),
        );

        expect(summary(), 'loading');
        expect(fallback(), 'pending');

        status.value = const LxSuccess<int>(99);
        expect(summary(), 'value:99');
        expect(fallback(), 'ok:99');

        status.value = const LxError<int>('failed');
        expect(summary(), 'err:failed');
        expect(fallback(), 'pending');

        status.value = LxIdle<int>();
        expect(summary(), 'idle');

        summary.close();
        fallback.close();
        status.close();
      },
    );
  });
}
