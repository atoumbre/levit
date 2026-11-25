# Security & Privacy Hardening Backlog

This document tracks security and privacy findings identified during the pre-`0.1.0` codebase audit that are deferred until the DevTools inspector (`levit_devtools` / `levit_devtools_ui`) is prepared for public release.

Runtime redaction, transport, `sessionId`, and opaque identifier hardening items (`levit_reactive`, `levit_monitor`, `levit_scope`, `levit_dart_core`) have been addressed.

---

## 1. `LevitInspectorServer` (`packages/tools/levit_devtools`)

### 1.1 Cross-Port CSWSH & DNS Rebinding
- **Location:** `packages/tools/levit_devtools/lib/levit_devtools.dart` (`_allowedOrigin`, `_serve`)
- **Risk:** High
- **Details:**
  - The HTTP server binds to `127.0.0.1` but does not validate the `Host` header. Under DNS rebinding, a page served from a rebinding domain on the same port can call `GET /health` or `GET /export?session=...` without an `Origin` header (`if (raw == null) return true;`).
  - `_allowedOrigin` checks `origin.scheme` and `origin.host`, but omits `origin.port == port`, `origin.userInfo.isEmpty`, and `origin.path.isEmpty`. Any page or dev server on another localhost port can connect to `/inspect` (reading live state, timelines, logs, and DI graphs) or `/ws` (spoofing producers or exhausting `maxSessions`).
  - `request.headers.value('origin')` throws `HttpException` on duplicate `Origin` headers, causing HTTP 500 and recording into `_failures`.
  - `/ws`, `/inspect`, and `/export` have no per-session authentication token; `/export` omits `Cache-Control: no-store`.
- **Planned Remediation:**
  - Strictly validate `Host` against `127.0.0.1:$port` and `localhost:$port` (reject missing or duplicate `Host` headers).
  - Inspect `request.headers['origin']` as a list; reject duplicates; require exact port match (`origin.port == port`) and empty `userInfo`/`path`/`query`/`fragment`.
  - Require a `Random.secure()` per-launch token on `/ws`, `/inspect`, and `/export`.
  - Add `Cache-Control: no-store` on `/export` and `X-Frame-Options: DENY` + CSP headers on HTML assets.

### 1.2 Arbitrary File Read on Windows & Symlink Escape in Static Asset Serving
- **Location:** `packages/tools/levit_devtools/lib/levit_devtools.dart` (static asset handler in `_serve`)
- **Risk:** High
- **Details:**
  - Path segment checks only reject `segment == '..' || segment.contains('/') || segment.contains('\\')`.
  - On Windows, `GET /C:/Windows/win.ini` yields segments `['C:', 'Windows', 'win.ini']`; `path.joinAll([assets.path, ...segments])` treats `'C:'` as a root prefix and discards `assets.path`.
  - `target.exists()` and `target.openRead()` follow symlinks without canonicalization, and null bytes (`%00`) trigger unhandled filesystem exceptions.
- **Planned Remediation:**
  - Reject segments containing `:`, `\x00`, or `..`.
  - Resolve symlinks on both `assets` and `target` (`resolveSymbolicLinks()`) and verify `path.isWithin(resolvedAssets, resolvedTarget)` before serving.

### 1.3 Unhandled WebSocket Errors, Malformed `scope_progress` Snapshots & Unbounded Connections
- **Locations:**
  - `packages/tools/levit_devtools/lib/levit_devtools.dart` (`_producer`, `_viewer`, `_Viewer._pump`)
  - `packages/core/levit_monitor/lib/src/snapshot.dart` (`applyEnvelope`, `_decodeScopeProgress`, `_restore`)
  - `packages/tools/levit_devtools_ui/lib/main.dart` (`_tasks`, channel teardown)
  - `packages/tools/levit_devtools/bin/levit_devtools.dart` (`ProcessSignal.sigterm.watch()`)
- **Risk:** High (Denial of Service / Crash)
- **Details:**
  - Both `_producer` and `_viewer` call `socket.listen(...)` without `onError`, and invoke `socket.add`/`socket.close` without `try/catch` or `.catchError`, allowing malformed frames or socket resets to crash the inspector process.
  - `LevitStateSnapshot.applyEnvelope` stores raw `_wireProgress` without validating tuple shape/types; malformed records are ACKed and later crash `/export`, viewer selection, and queue recovery. `LevitStateSnapshot._restore` clears all snapshot maps before validating incoming state.
  - `LevitInspectorServer` has no connection/viewer caps or pre-handshake timeouts; `LevitStateSnapshot.variables` is unbounded and not pruned on `scope_dispose`.
  - `levit_devtools_ui` has unguarded casts and unbounded recursion in `_tasks()` tree rendering, and `export_web.dart` calls `window.open` without `'noopener,noreferrer'`.
  - `bin/levit_devtools.dart` calls `ProcessSignal.sigterm.watch()` unconditionally, which throws `SignalException` on Windows.
- **Planned Remediation:**
  - Attach `onError` handlers and guard `socket.add`/`close`.
  - Validate `scope_progress` eagerly in `applyEnvelope` and parse `_restore` atomically before replacing state.
  - Enforce max connections/viewers/variables, prune `variables` on `scope_dispose`, bound task tree depth in the UI, guard `sigterm` with `!Platform.isWindows`, and add `'noopener,noreferrer'` to `export_web.dart`.
