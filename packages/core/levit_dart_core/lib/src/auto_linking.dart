part of 'dart_core_library.dart';

final class _CaptureState {
  bool active = true;
}

/// Internal scope for capturing reactive objects creation.
///
/// Uses [Zone] values to intercept [LxReactive] objects initialized within
/// its callback context.
class _AutoLinkScope {
  static int _activeCaptureScopes = 0;

  static final Object _captureKey = Object();
  static final Object _captureStateKey = Object();
  static final Object _ownerIdKey = Object();

  /// The Zone key used to store the capture list.
  static Object get captureKey => _captureKey;

  static R runCaptured<R>(
    R Function() builder,
    void Function(List<LxReactive> captured, dynamic result) processor, {
    String? ownerId,
    void Function(Future<void> operation)? onSettled,
  }) {
    R core() {
      if (_activeCaptureScopes == 0 && !LxSpi.hasInitMiddlewares) {
        final result = builder();
        if (result is Future && onSettled != null) {
          onSettled(
            result.then<void>((_) {}, onError: (Object _, StackTrace __) {}),
          );
        }
        return result;
      }

      // A nested registration owns its allocations even when another owner's
      // builder is the first caller to resolve it.
      final captured = <LxReactive>[];
      final state = _CaptureState();

      _activeCaptureScopes++;
      try {
        final R result = runZoned(
          builder,
          zoneValues: {
            _captureKey: captured,
            _captureStateKey: state,
            if (ownerId != null) _ownerIdKey: ownerId,
          },
        );

        if (result is Future) {
          final processing = result
              .then<void>(
                (resolvedResult) {
                  processor(captured, resolvedResult);
                },
                onError: (Object _, StackTrace __) async {
                  await _disposeCaptured(captured);
                },
              )
              .whenComplete(() {
                state.active = false;
                _activeCaptureScopes--;
              });
          if (onSettled != null) {
            onSettled(processing);
          } else {
            unawaited(
              processing.catchError((Object error, StackTrace stack) {
                Zone.current.handleUncaughtError(error, stack);
              }),
            );
          }
        } else {
          state.active = false;
          processor(captured, result);
          _activeCaptureScopes--;
        }

        return result;
      } catch (e) {
        state.active = false;
        final cleanup = _disposeCaptured(captured);
        if (onSettled != null) {
          onSettled(cleanup);
        } else {
          unawaited(cleanup);
        }
        _activeCaptureScopes--;
        rethrow;
      }
    }

    if (ownerId != null) {
      return LxSpi.runWithOwner(ownerId, core);
    }
    return core();
  }

  static Future<void> _disposeCaptured(List<LxReactive> captured) async {
    final failures = <LevitDisposalFailure>[];
    for (final reactive in captured.reversed) {
      try {
        await reactive.close();
      } catch (error, stackTrace) {
        failures.add(
          LevitDisposalFailure(
            resource: reactive,
            error: error,
            stackTrace: stackTrace,
          ),
        );
      }
    }
    if (failures.isNotEmpty) throw LevitDisposalException.aggregate(failures);
  }

  static S Function() _createCaptureHook<S>(
    S Function() builder,
    String key,
    LevitDependency info,
  ) {
    return () => _AutoLinkScope.runCaptured(
      builder,
      (captured, instance) => _processInstance(instance, captured),
      ownerId: key,
      onSettled: info.trackInitialization,
    );
  }

  static void Function() _createCaptureHookInit<S>(
    void Function() onInit,
    String key,
    S instance,
    LevitDependency info,
  ) {
    return () {
      // Controllers use live capture so async onInit allocations are linked immediately.
      List<LxReactive> captured;
      if (instance is LevitController) {
        captured = _LiveCaptureList(instance);
      } else {
        captured = <LxReactive>[];
      }

      _AutoLinkScope._activeCaptureScopes++;
      final state = _CaptureState();
      try {
        // `onInit` may return `Future` despite the static `void` signature.
        final dynamic result = LxSpi.runWithOwner(
          key,
          () => runZoned(
            () => instance is LevitController
                ? instance._runInitialization(() => (onInit as dynamic)())
                : (onInit as dynamic)(),
            zoneValues: {
              _captureKey: captured,
              _captureStateKey: state,
              _ownerIdKey: key,
            },
          ),
        );

        if (result is Future) {
          final initialization = result
              .whenComplete(() {
                state.active = false;
                _AutoLinkScope._activeCaptureScopes--;
              })
              .then<void>((_) {});
          if (instance is LevitController) {
            instance._trackCapturedInitialization(initialization);
            info.trackInitialization(
              initialization.then<void>(
                (_) {},
                onError: (Object _, StackTrace __) {},
              ),
            );
          } else {
            info.trackInitialization(initialization);
          }
        } else {
          state.active = false;
          _AutoLinkScope._activeCaptureScopes--;
        }
      } catch (e) {
        state.active = false;
        _AutoLinkScope._activeCaptureScopes--;
        rethrow;
      }
    };
  }

  static void _processInstance(dynamic instance, List<LxReactive> captured) {
    if (instance is LevitController) {
      for (final reactive in captured) {
        instance.own(reactive);
      }
    }
  }
}

class _AutoLinkMiddleware extends LevitReactiveMiddleware {
  @override
  void Function(LxReactive)? get onInit => (reactive) {
    // Fast exit when neither capture nor owner context is active.
    final context = LxSpi.listenerContext;
    final hasOwnerContext = context != null && context.type == 'Owner';

    if (_AutoLinkScope._activeCaptureScopes == 0 && !hasOwnerContext) {
      return;
    }

    if (!LxSpi.deferAutoLink(
      reactive,
      () => _captureReactiveIfNeeded(reactive),
    )) {
      _captureReactiveIfNeeded(reactive);
    }
    _assignReactiveOwnerIfNeeded(reactive, context, hasOwnerContext);
  };
}

String _missingCaptureListWarning(LxReactive reactive) =>
    'Levit: Reactive "${reactive.name ?? reactive.runtimeType}" created inside an active capture scope but no capture list found in current Zone. This may indicate the reactive was created in a different Zone (e.g., runZonedGuarded). Use own() to manually register it.';

void _emitAutoLinkDebugWarning(String message) {
  assert(() {
    dev.log(message, name: 'levit_dart');
    Zone.current.print(message);
    return true;
  }());
}

void _captureReactiveIfNeeded(LxReactive reactive) {
  if (_AutoLinkScope._activeCaptureScopes <= 0) return;

  final captureList = Zone.current[_AutoLinkScope._captureKey];
  final captureState = Zone.current[_AutoLinkScope._captureStateKey];
  if (captureState is _CaptureState && !captureState.active) {
    if (captureList is _LiveCaptureList && captureList._owner.isDisposed) {
      captureList.add(reactive);
    }
    return;
  }

  if (captureList is List<LxReactive>) {
    captureList.add(reactive);
  } else {
    _emitAutoLinkDebugWarning(_missingCaptureListWarning(reactive));
  }
}

void _assignReactiveOwnerIfNeeded(
  LxReactive reactive,
  dynamic context,
  bool hasOwnerContext,
) {
  if (reactive.ownerId != null) return;

  final captureState = Zone.current[_AutoLinkScope._captureStateKey];
  if (captureState is! _CaptureState || captureState.active) {
    final zonedOwnerId = Zone.current[_AutoLinkScope._ownerIdKey] as String?;
    if (zonedOwnerId != null) {
      reactive.ownerId = zonedOwnerId;
      return;
    }
  }

  if (!hasOwnerContext) return;

  final data = context.data;
  if (data is Map<String, dynamic>) {
    reactive.ownerId = data['ownerId'] as String?;
  }
}

class _AutoDisposeMiddleware extends LevitScopeMiddleware {
  /// Intercepts dependency creation to wrap the builder in a capture scope.
  @override
  S Function() onDependencyCreate<S>(
    S Function() builder,
    LevitScope scope,
    String key,
    LevitDependency info,
  ) {
    final scopedKey = '${scope.id}:$key';
    return _AutoLinkScope._createCaptureHook(builder, scopedKey, info);
  }

  /// Intercepts [onInit] execution to capture reactives created during initialization.
  @override
  void Function() onDependencyInit<S>(
    void Function() onInit,
    S instance,
    LevitScope scope,
    String key,
    LevitDependency info,
  ) {
    final scopedKey = '${scope.id}:$key';
    return _AutoLinkScope._createCaptureHookInit(
      onInit,
      scopedKey,
      instance,
      info,
    );
  }
}

class _LiveCaptureList extends ListBase<LxReactive> {
  final List<LxReactive> _inner = [];
  final LevitController _owner;

  _LiveCaptureList(this._owner);

  @override
  int get length => _inner.length;

  @override
  set length(int newLength) => _inner.length = newLength;

  @override
  LxReactive operator [](int index) => _inner[index];

  @override
  void operator []=(int index, LxReactive value) {
    _inner[index] = value;
  }

  @override
  void add(LxReactive element) {
    _inner.add(element);

    // Register on insert so capture order cannot race with async init logic.
    _owner._adoptCaptured(element);
  }
}

/// Internal auto-linking hooks exposed via `package:levit_dart_core/spi.dart`.
///
/// {@category SPI}
abstract final class LevitAutoLinkSpi {
  /// The [Zone] key used to store the active auto-link capture list.
  static Object get captureKey => _AutoLinkScope.captureKey;

  /// Runs [builder] inside an auto-link capture zone without adopting results.
  static R runCaptured<R>(R Function() builder, [String? ownerId]) {
    return _AutoLinkScope.runCaptured(
      builder,
      (captured, result) {},
      ownerId: ownerId,
    );
  }
}
