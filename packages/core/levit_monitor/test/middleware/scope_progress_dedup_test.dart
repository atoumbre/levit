import 'dart:async';

import 'package:levit/levit.dart';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';

class _Sink extends LevitTransport {
  final events = <MonitorEvent>[];
  @override
  void send(MonitorEvent event) => events.add(event);
}

class _ClosingResource extends LevitScopeDisposable {
  final release = Completer<void>();
  @override
  Future<void> onClose() => release.future;
}

void main() {
  test(
    'terminal disposal replaces empty progress only after real cleanup',
    () async {
      for (final fail in [false, true]) {
        final sink = _Sink();
        final monitor = LevitMonitorMiddleware(transport: sink)..enable();
        final scope = LevitScope.root('closing');
        final resource = scope.put(_ClosingResource.new);
        final closing = scope.dispose();
        final completion = expectLater(
          closing,
          fail ? throwsA(isA<LevitDisposalException>()) : completes,
        );
        await monitor.flush();
        expect(
          sink.events.any((event) => event.toJson()['type'] == 'scope_dispose'),
          isFalse,
        );
        final progress =
            (monitor.snapshot['scopes'] as List).single['progress'] as Map;
        expect(progress['isClosing'], isTrue);
        expect((progress['registrations'] as List).single['isClosing'], isTrue);
        if (fail) {
          resource.release.completeError(StateError('cleanup failed'));
        } else {
          resource.release.complete();
        }
        await completion;
        await monitor.flush();
        expect(sink.events.last.toJson()['type'], 'scope_dispose');
        expect(monitor.snapshot['scopes'], isEmpty);
        expect(monitor.droppedEvents, 0);
        for (final event in sink.events) {
          final wire = event.toJson();
          if (wire['type'] == 'scope_progress') {
            expect(((wire['scope'] as List)[2] as int) & 2, 0);
          }
          if (wire['type'] == 'scope_create' ||
              wire['type'] == 'scope_dispose') {
            expect(wire.containsKey('isFactory'), isFalse);
            expect(wire.containsKey('key'), isFalse);
            expect(wire['scopeName'], 'closing');
          }
        }
        await monitor.close();
      }
    },
  );

  test(
    'only identical progress is suppressed; ownership and cleanup changes survive',
    () async {
      final sink = _Sink();
      final monitor = LevitMonitorMiddleware(
        transport: sink,
        historyCapacity: 20,
      )..enable();
      LevitScopeDescription progress({
        int pending = 0,
        bool closing = false,
        bool disposed = false,
        int? ancestor = 2,
        bool child = false,
        bool registration = true,
      }) => LevitScopeDescription(
        id: 1,
        name: 'feature',
        isClosing: closing,
        isDisposed: disposed,
        pendingInitializations: pending,
        ancestry: [
          if (ancestor != null) LevitScopeIdentity(ancestor, 'parent'),
        ],
        ownedChildren: [if (child) const LevitScopeIdentity(3, 'child')],
        registrations: [
          if (registration)
            LevitRegistrationDescription(
              key: 'repo',
              type: 'Repository',
              pendingInitializations: pending,
              isClosing: closing,
              isFactory: pending > 0,
              isAsync: pending > 0,
              isLazy: pending > 0,
              permanent: pending > 0,
              isInstantiated: closing,
              ownedInstances: closing ? 2 : 0,
            ),
          if (child)
            const LevitRegistrationDescription(
              key: 'alias',
              type: 'Api',
              aliasOf: 'repo',
            ),
        ],
      );
      final states = [
        progress(),
        progress(pending: 1),
        progress(pending: 1, closing: true),
        progress(closing: true),
        progress(closing: true, ancestor: 4),
        progress(closing: true, ancestor: 4, child: true),
        progress(closing: true, pending: 1, registration: false),
        progress(closing: true, disposed: true),
        progress(ancestor: null),
      ];
      for (final state in states) {
        monitor.onScopeProgress(state);
        monitor.onScopeProgress(state);
      }
      await monitor.flush();
      expect(sink.events.length, states.length);
      expect(monitor.history.length, states.length);
      expect(monitor.droppedEvents, 0);
      for (var i = 0; i < states.length; i++) {
        // Each event reconstructs the complete state in isolation. Missing older
        // events never turns the compact representation into a partial delta.
        final replay = StateSnapshot()..applyEvent(sink.events[i]);
        expect(replay.scopes[1]!.progress, states[i].toJson());
        final wire = sink.events[i].toJson();
        expect(wire['type'], 'scope_progress');
        expect(() => (wire['scope'] as List).clear(), throwsUnsupportedError);
      }
      final latest = (monitor.snapshot['scopes'] as List).single as Map;
      expect(latest['progress'], states.last.toJson());
      final unsupported = LevitEventEnvelope({
        ...sink.events.first.toJson(),
        'version': 2,
      });
      expect(
        () => StateSnapshot().applyEnvelope(unsupported),
        throwsFormatException,
      );
      await monitor.close();
    },
  );
}
