import 'package:levit_mcp/levit_mcp.dart';
import 'package:test/test.dart';

void main() {
  group('LevitRelaySecurity handshake validation', () {
    test(
      'constantTimeEquals compares equal and unequal strings accurately',
      () {
        expect(constantTimeEquals('secret-123', 'secret-123'), isTrue);
        expect(constantTimeEquals('secret-123', 'secret-124'), isFalse);
        expect(constantTimeEquals('short', 'much-longer'), isFalse);
        expect(constantTimeEquals('', ''), isTrue);
      },
    );

    test('isValidLoopbackHost accepts single loopback Host matching port', () {
      expect(
        LevitRelaySecurity.isValidLoopbackHost(['127.0.0.1:9200'], 9200),
        isTrue,
      );
      expect(
        LevitRelaySecurity.isValidLoopbackHost(['LOCALHOST:9200'], 9200),
        isTrue,
      );
      expect(LevitRelaySecurity.isValidLoopbackHost(null, 9200), isFalse);
      expect(LevitRelaySecurity.isValidLoopbackHost([], 9200), isFalse);
      expect(
        LevitRelaySecurity.isValidLoopbackHost([
          '127.0.0.1:9200',
          'localhost:9200',
        ], 9200),
        isFalse,
      );
      expect(
        LevitRelaySecurity.isValidLoopbackHost(['evil.example:9200'], 9200),
        isFalse,
      );
      expect(
        LevitRelaySecurity.isValidLoopbackHost(['127.0.0.1:9201'], 9200),
        isFalse,
      );
    });

    test('isAllowedOrigin permits absent Origin and enforces allowlist', () {
      expect(LevitRelaySecurity.isAllowedOrigin(null, const {}), isTrue);
      expect(LevitRelaySecurity.isAllowedOrigin(const [], const {}), isTrue);
      expect(
        LevitRelaySecurity.isAllowedOrigin(['http://localhost:8080'], const {}),
        isFalse,
      );
      expect(
        LevitRelaySecurity.isAllowedOrigin(
          ['http://localhost:8080', 'http://localhost:8080'],
          {'http://localhost:8080'},
        ),
        isFalse,
      );
      expect(
        LevitRelaySecurity.isAllowedOrigin(
          ['HTTP://LOCALHOST:8080'],
          {'http://localhost:8080'},
        ),
        isTrue,
      );
      expect(
        LevitRelaySecurity.isAllowedOrigin(
          ['http://localhost:8080/path'],
          {'http://localhost:8080'},
        ),
        isFalse,
      );
      expect(
        LevitRelaySecurity.isAllowedOrigin(
          ['ws://localhost:8080'],
          {'http://localhost:8080'},
        ),
        isFalse,
      );
      expect(
        LevitRelaySecurity.isAllowedOrigin(
          ['http://user@localhost:8080'],
          {'http://localhost:8080'},
        ),
        isFalse,
      );
    });

    test('normalizeOrigin rejects malformed or non-HTTP origins', () {
      expect(LevitRelaySecurity.normalizeOrigin('not-a-uri'), isNull);
      expect(LevitRelaySecurity.normalizeOrigin('ftp://localhost:21'), isNull);
      expect(
        LevitRelaySecurity.normalizeOrigin('https://example.com'),
        'https://example.com',
      );
      expect(
        LevitRelaySecurity.normalizeOrigin('http://localhost:3000?a=1'),
        isNull,
      );
    });

    test('isAuthorized validates Bearer header and query token', () {
      expect(
        LevitRelaySecurity.isAuthorized(
          authorizationHeaders: ['Bearer tok-1'],
          queryToken: null,
          expectedToken: 'tok-1',
        ),
        isTrue,
      );
      expect(
        LevitRelaySecurity.isAuthorized(
          authorizationHeaders: ['Bearer wrong'],
          queryToken: 'tok-1',
          expectedToken: 'tok-1',
        ),
        isFalse,
      );
      expect(
        LevitRelaySecurity.isAuthorized(
          authorizationHeaders: ['Basic abc'],
          queryToken: 'tok-1',
          expectedToken: 'tok-1',
        ),
        isFalse,
      );
      expect(
        LevitRelaySecurity.isAuthorized(
          authorizationHeaders: ['Bearer tok-1', 'Bearer tok-1'],
          queryToken: null,
          expectedToken: 'tok-1',
        ),
        isFalse,
      );
      expect(
        LevitRelaySecurity.isAuthorized(
          authorizationHeaders: null,
          queryToken: 'tok-1',
          expectedToken: 'tok-1',
        ),
        isTrue,
      );
      expect(
        LevitRelaySecurity.isAuthorized(
          authorizationHeaders: null,
          queryToken: null,
          expectedToken: 'tok-1',
        ),
        isFalse,
      );
      expect(
        LevitRelaySecurity.isAuthorized(
          authorizationHeaders: null,
          queryToken: 'wrong',
          expectedToken: 'tok-1',
        ),
        isFalse,
      );
    });
  });
}
