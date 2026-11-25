# levit_devtools

A read-only local inspector for Levit applications. The Dart CLI serves bundled
Flutter web assets and a WebSocket relay on **127.0.0.1:9200**. No Flutter SDK,
remote service, or hosted account is needed to run the published CLI.
Requires Dart 3.12 or later.

```sh
dart pub global activate levit_devtools 0.1.0-beta.1
dart pub global run levit_devtools
# Use another loopback port when 9200 is occupied:
dart pub global run levit_devtools --port 9201
```

Open the printed URL. Attach each application before creating its feature scopes:

```dart
await LevitMonitor.attach(
  transport: WebSocketTransport.connect(
    'ws://127.0.0.1:9200/ws', appId: 'my-app'),
  historyCapacity: 1000,
  enableWorkerStatistics: true,
  includeStackTrace: true,
);
// Shut down application owners, then drain diagnostic delivery.
await LevitMonitor.detach();
```

Import `package:levit_monitor/levit_monitor.dart` in the producer. Mark sensitive
reactive values at construction, before their initialization event. Names, keys,
and custom event attributes should contain diagnostic identifiers, not secrets.

## Inspector views

- **Sessions:** select the app or server, with connection status and session ID.
- **Ownership:** scope ancestry, registrations, controllers/stores, and owned state.
- **Reactions:** dependency relationships and listeners.
- **Timeline:** filter by category or text, inspect old/new values, owner IDs, batch
  membership, and optional write call stacks to investigate update causes.
- **Tasks:** group hierarchy, pending/running counts, deadlines and cancellation
  reasons from the optional application adapter in the monitor example.
- **Cleanup:** scopes still initializing or closing and their pending registrations.
- **Export JSON:** download the selected session's redacted state and retained events.

The tool cannot mutate application state. `/ws` remains the producer endpoint;
`/inspect` accepts session selection and delivery acknowledgements only. The HTTP
server binds to IPv4 loopback and rejects foreign browser origins.

## Bounded delivery and reconnects

Defaults are 16 sessions, 1,000 events or 4 MiB of history per session, 1 MiB per
incoming envelope, and 256 pending messages per viewer. Active sessions are pinned;
inactive sessions can be evicted when capacity is reached. Producers and viewers
acknowledge delivery. Slow-viewer overflow replaces queued deltas with a current
snapshot. Producer reconnects also send a snapshot. Neither claims a complete
history: the UI and export distinguish producer drops, history evictions, sequence
gaps and viewer drops. Disconnecting does not erase the last known state.

The relay rechecks sensitive fields before buffering. This is a local diagnostic
tool, not a durable audit log. Shut it down with Ctrl-C; sockets and pending HTTP
requests finish before the CLI exits.

Awaited shutdown reports retained HTTP request and cleanup failures after all
release attempts. A failed streamed response cannot overwrite its original
error by trying to resend headers. Embedded launchers may pass a package-URI
resolver to `LevitInspectorServer.bundledAssets` when using a custom package map.

## Developing in this repository

The Flutter source is the private `levit_devtools_ui` workspace package. From the
repository root, run `dart run scripts/build_devtools.dart` to rebuild release
assets with bundled Roboto and local CanvasKit resources and copy them into `lib/assets`. Commit the
bundle with the source change; the CLI package contains the ready-to-serve UI.

Run `dart test` here (including the packaged startup test), `flutter test` in the
private UI, and fatal-info analysis in both packages. Melos, aggregate CI, coverage
and publication discovery include the new packages; publication excludes the
private UI. Before publishing, resolve all coordinated 0.1.0 packages together
and run the repository's publication dry-runs.
