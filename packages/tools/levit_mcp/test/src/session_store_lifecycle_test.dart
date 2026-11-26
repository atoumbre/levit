import 'package:levit_mcp/levit_mcp.dart';
import 'package:levit_monitor/spi.dart';
import 'package:test/test.dart';

void main() {
  group('LevitSessionStore lifecycle and resolution', () {
    test(
      'tracks sessions, evicts disconnected sessions at capacity, and enforces active cap',
      () {
        var tick = 0;
        final store = LevitSessionStore(
          maxSessions: 2,
          historyCapacity: 10,
          clock: () => DateTime.utc(2026, 1, 1, 0, 0, tick++),
        );

        final s1 = store.openSession('s1', appId: 'app-1');
        expect(s1.appId, 'app-1');
        expect(store['s1'], same(s1));

        // Reopening updates appId and activity timestamp.
        store.openSession('s1', appId: 'app-1-v2');
        expect(s1.appId, 'app-1-v2');

        store.openSession('s2', appId: 'app-2');
        expect(() => store.openSession('s3'), throwsStateError);

        // Marking unknown session disconnected is a no-op.
        store.markDisconnected('missing');

        // Disconnecting s1 allows s3 to evict s1.
        store.markDisconnected('s1');
        final s3 = store.openSession('s3', appId: 'app-3');
        expect(store['s1'], isNull);
        expect(store['s3'], same(s3));
        expect(store.sessions.length, 2);
      },
    );

    test('records error envelopes in a bounded ring and updates summaries', () {
      final store = LevitSessionStore(historyCapacity: 5);
      final session = store.openSession('s1', appId: 'demo');

      for (var i = 0; i < 55; i++) {
        store.applyEnvelope(
          's1',
          LevitEventEnvelope({
            'seq': i + 1,
            'type': i.isEven ? 'reactive_error' : 'log',
            'level': 'error',
            'timestamp': '2026-01-01T00:00:00Z',
            'reactiveId': 7,
            'name': 'broken',
            'error': 'boom-$i',
            'data': 'log-$i',
          }),
        );
      }

      expect(session.eventCount, 55);
      expect(session.recentErrors.length, session.maxRecentErrors);
      expect(session.toSummaryJson()['errorCount'], 50);
    });

    test(
      'resolves single active, single retained, explicit, and ambiguous sessions',
      () {
        final store = LevitSessionStore();

        expect(store.resolveSession(null).error, contains('No Levit sessions'));
        expect(
          store.resolveSession('missing').error,
          contains('Unknown sessionId'),
        );

        final s1 = store.openSession('s1');
        expect(store.resolveSession(null).session, same(s1));
        expect(store.resolveSession('s1').session, same(s1));

        store.markDisconnected('s1');
        expect(store.resolveSession(null).session, same(s1));

        final s2 = store.openSession('s2');
        expect(store.resolveSession(null).session, same(s2));

        store.openSession('s1');
        final ambiguous = store.resolveSession(null);
        expect(ambiguous.session, isNull);
        expect(ambiguous.error, contains('Multiple sessions available'));
      },
    );
  });
}
