import 'dart:math';

import 'package:levit_mcp/levit_mcp.dart';
import 'package:test/test.dart';

void main() {
  group('LevitMcpConfig parsing and validation', () {
    test('generates a 32-character hexadecimal token by default', () {
      final token = generateAuthToken(Random(42));
      expect(token.length, 32);
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(token), isTrue);

      final config = LevitMcpConfig(random: Random(7));
      expect(config.tokenGenerated, isTrue);
      expect(config.token.length, 32);
      expect(config.port, LevitMcpConfig.defaultPort);
    });

    test('validates numeric range bounds on constructor parameters', () {
      expect(() => LevitMcpConfig(port: -1), throwsRangeError);
      expect(() => LevitMcpConfig(port: 70000), throwsRangeError);
      expect(() => LevitMcpConfig(maxSessions: 0), throwsRangeError);
      expect(() => LevitMcpConfig(maxConnections: 0), throwsRangeError);
      expect(() => LevitMcpConfig(maxMessageBytes: 512), throwsRangeError);
      expect(() => LevitMcpConfig(historyCapacity: -1), throwsRangeError);
      expect(() => LevitMcpConfig(maxVariables: 0), throwsRangeError);
      expect(() => LevitMcpConfig(maxTaskTreeDepth: 0), throwsRangeError);
    });

    test('parses CLI options and falls back to LEVIT_MCP_TOKEN env var', () {
      final fromCli = LevitMcpConfig.parseArgs([
        '--port',
        '9301',
        '--token',
        'cli-secret',
        '--allow-web-origin',
        'http://localhost:8080',
        '--history-capacity',
        '250',
        '--max-sessions',
        '8',
        '--max-connections',
        '12',
      ]);
      expect(fromCli, isNotNull);
      expect(fromCli!.port, 9301);
      expect(fromCli.token, 'cli-secret');
      expect(fromCli.tokenGenerated, isFalse);
      expect(fromCli.allowWebOrigins, {'http://localhost:8080'});
      expect(fromCli.historyCapacity, 250);
      expect(fromCli.maxSessions, 8);
      expect(fromCli.maxConnections, 12);

      final fromEnv = LevitMcpConfig.parseArgs(
        const [],
        environment: {'LEVIT_MCP_TOKEN': 'env-secret'},
      );
      expect(fromEnv!.token, 'env-secret');
      expect(fromEnv.tokenGenerated, isFalse);

      final generated = LevitMcpConfig.parseArgs(const [], random: Random(1));
      expect(generated!.tokenGenerated, isTrue);
      expect(generated.token.length, 32);
    });

    test('returns null on --help and exposes usage text', () {
      expect(LevitMcpConfig.parseArgs(const ['--help']), isNull);
      expect(LevitMcpConfig.usage, contains('--port'));
      expect(LevitMcpConfig.usage, contains('--token'));
    });

    test('rejects invalid numeric CLI option values', () {
      expect(
        () => LevitMcpConfig.parseArgs(const ['--port', 'abc']),
        throwsFormatException,
      );
      expect(
        () => LevitMcpConfig.parseArgs(const ['--port', '99999']),
        throwsFormatException,
      );
      expect(
        () => LevitMcpConfig.parseArgs(const ['--max-sessions', '0']),
        throwsFormatException,
      );
    });
  });
}
