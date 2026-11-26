/// Read-only Flutter DevTools extension host and Dart VM Service transport for
/// live Levit runtime inspection.
///
/// Add `levit_devtools` to a Dart or Flutter application and call
/// [LevitDevTools.attach] during bootstrap (automatically a no-op in release
/// builds) to expose redacted scopes, reactive state, task trees, event
/// history, and deterministic diagnostics over `dart:developer`.
///
/// ## Key Components
///
/// - [LevitDevTools]: High-level bootstrap facade (`attach` / `detach`).
/// - [LevitVmServiceTransport]: `LevitTransport` backed by `dart:developer`
///   service extensions and `postEvent`.
/// - [LevitDevToolsProtocol]: Stable VM Service extension names, event kind,
///   and protocol version constants.
///
/// @docImport 'src/vm_service_transport.dart';
library;

export 'src/vm_service_transport.dart'
    show
        LevitDevTools,
        LevitDevToolsProtocol,
        LevitVmServicePostEvent,
        LevitVmServiceRegisterExtension,
        LevitVmServiceTransport;
