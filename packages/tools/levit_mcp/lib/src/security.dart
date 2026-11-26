import 'dart:convert';

/// Compares two UTF-8 strings without early exit on byte mismatches.
///
/// Execution time is independent of byte values when [a] and [b] have the same
/// UTF-8 byte length; iteration count scales with `min(aBytes.length, bBytes.length)`.
///
/// {@category Relay & Security}
bool constantTimeEquals(String a, String b) {
  final aBytes = utf8.encode(a);
  final bBytes = utf8.encode(b);
  var diff = aBytes.length ^ bBytes.length;
  final length = aBytes.length < bBytes.length ? aBytes.length : bBytes.length;
  for (var i = 0; i < length; i++) {
    diff |= aBytes[i] ^ bBytes[i];
  }
  return diff == 0;
}

/// Security validators for incoming loopback WebSocket producer handshakes.
///
/// {@category Relay & Security}
abstract final class LevitRelaySecurity {
  /// Validates that `Host` is present exactly once and targets IPv4 loopback
  /// [port].
  ///
  /// Accepts only `127.0.0.1:<port>` and `localhost:<port>` (case-insensitive)
  /// to match `InternetAddress.loopbackIPv4`; IPv6 `[::1]` and duplicate
  /// headers are rejected.
  static bool isValidLoopbackHost(List<String>? hostHeaders, int port) {
    if (hostHeaders == null || hostHeaders.length != 1) return false;
    final normalized = hostHeaders.first.trim().toLowerCase();
    return normalized == '127.0.0.1:$port' || normalized == 'localhost:$port';
  }

  /// Validates the `Origin` header against [allowedWebOrigins].
  ///
  /// Requests without an `Origin` header (native Dart/Flutter IO clients) are
  /// permitted. Duplicate `Origin` headers or origins outside the allowlist are
  /// rejected to prevent Cross-Site WebSocket Hijacking (CSWSH).
  static bool isAllowedOrigin(
    List<String>? originHeaders,
    Set<String> allowedWebOrigins,
  ) {
    if (originHeaders == null || originHeaders.isEmpty) return true;
    if (originHeaders.length != 1) return false;
    final normalized = normalizeOrigin(originHeaders.first);
    if (normalized == null) return false;
    for (final allowed in allowedWebOrigins) {
      if (normalizeOrigin(allowed) == normalized) return true;
    }
    return false;
  }

  /// Normalizes an HTTP/HTTPS origin into `scheme://host[:port]` or returns
  /// `null` if the string contains userinfo, path, query, fragment, or an
  /// unsupported scheme.
  static String? normalizeOrigin(String raw) {
    final trimmed = raw.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null;
    if (uri.userInfo.isNotEmpty ||
        uri.path.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    final portSuffix = uri.hasPort ? ':${uri.port}' : '';
    return '$scheme://${uri.host.toLowerCase()}$portSuffix';
  }

  /// Validates the producer authentication token supplied via either
  /// `Authorization: Bearer <token>` or the `?token=` query parameter.
  ///
  /// When an `Authorization` header is present, it takes strict precedence:
  /// duplicate headers, a missing case-sensitive `'Bearer '` prefix, an empty
  /// token, or a token mismatch immediately returns `false` without falling
  /// back to [queryToken]. Comparisons use [constantTimeEquals].
  static bool isAuthorized({
    required List<String>? authorizationHeaders,
    required String? queryToken,
    required String expectedToken,
  }) {
    if (authorizationHeaders != null && authorizationHeaders.isNotEmpty) {
      if (authorizationHeaders.length != 1) return false;
      final header = authorizationHeaders.first.trim();
      const prefix = 'Bearer ';
      if (!header.startsWith(prefix)) return false;
      final supplied = header.substring(prefix.length);
      return supplied.isNotEmpty && constantTimeEquals(supplied, expectedToken);
    }
    if (queryToken == null || queryToken.isEmpty) return false;
    return constantTimeEquals(queryToken, expectedToken);
  }
}
