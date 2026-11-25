# Levit Inspector UI (private)

Flutter web source for the read-only local inspector bundled by `levit_devtools`.
This package is not published. Requires Flutter 3.44 and Dart 3.12 or later.

Run `flutter test` and `dart analyze --fatal-infos` here. From the repository root,
run `dart run scripts/build_devtools.dart` to build and stage the release bundle.
The UI uses the same host's `/inspect` WebSocket and `/export` endpoint; run the
CLI to test the complete bundle. No remote backend is used. See the CLI README
for session selection, views, queue bounds, reconnect semantics and redaction.

Reconnect callbacks apply only to their own connection. A failed obsolete
handshake cannot disconnect the replacement. Malformed cyclic ownership records
remain visible with a cycle diagnostic instead of disappearing from the tree.
