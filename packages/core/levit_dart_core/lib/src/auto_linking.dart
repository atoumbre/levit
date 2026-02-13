part of '../levit_dart_core.dart';

/// Internal scope for capturing reactive objects creation.
///
/// Uses [Zone] values to intercept [LxReactive] objects initialized within
/// its callback context.
class _AutoLinkScope {
  static int _activeCaptureScopes = 0;

  static final Object _captureKey = Object();
  static final Object _ownerIdKey = Object();

  /// The Zone key used to store the capture list.
  static Object get captureKey => _captureKey;

  static R runCaptured<R>(
    R Function() builder,
    void Function(List<LxReactive> captured, dynamic result) processor, {
    String? ownerId,
  }) {
    R core() {
      if (_activeCaptureScopes == 0 &&
          !LevitReactiveMiddleware.hasInitMiddlewares) {
        return builder();
      }

      final captured = <LxReactive>[];
      final parentList = Zone.current[_captureKey] as List<LxReactive>?;
      final proxyList = parentList != null
          ? _ChainedCaptureList(captured, parentList)
          : captured;

      _activeCaptureScopes++;
      try {
        final R result = runZoned(
          builder,
          zoneValues: {
            _captureKey: proxyList,
            if (ownerId != null) _ownerIdKey: ownerId,
          },
        );

        if (result is Future) {
          result.then((resolvedResult) {
            processor(captured, resolvedResult);
          }).catchError((_) {
            _disposeCaptured(captured);
          }).whenComplete(() {
            _activeCaptureScopes--;
          });
        } else {
          processor(captured, result);
          _activeCaptureScopes--;
        }

        return result;
      } catch (e) {
        _disposeCaptured(captured);
        _activeCaptureScopes--;
        rethrow;
      }
    }

    if (ownerId != null) {
      return Lx.runWithOwner(ownerId, core);
    }
    return core();
  }

  static void _disposeCaptured(List<LxReactive> captured) {
    for (final reactive in captured) {
      reactive.close();
    }
  }

  static S Function() _createCaptureHook<S>(
    S Function() builder,
    String key,
  ) {
    return () => _AutoLinkScope.runCaptured(
          builder,
          (captured, instance) => _processInstance(instance, captured, key),
          ownerId: key,
        );
  }

  static void Function() _createCaptureHookInit<S>(
    void Function() onInit,
    String key,
    S instance,
  ) {
    return () {
      // Determine the capture list implementation
      List<LxReactive> captured;
      if (instance is LevitController) {
        // Use "Live Capture" for controllers.
        // This immediately registers and auto-disposes variables as they are created,
        // creating a robust solution for async onInit scenarios.
        captured = _LiveCaptureList(instance);
      } else {
        captured = <LxReactive>[];
      }

      final parentList =
          Zone.current[_AutoLinkScope._captureKey] as List<LxReactive>?;
      final proxyList = parentList != null
          ? _ChainedCaptureList(captured, parentList)
          : captured;

      _AutoLinkScope._activeCaptureScopes++;
      try {
        // Cast to dynamic to allow capturing return value (Future or null)
        // from a statically typed void Function().
        final dynamic result = runZoned(
          () => (onInit as dynamic)(),
          zoneValues: {
            _AutoLinkScope._captureKey: proxyList,
            _AutoLinkScope._ownerIdKey: key,
          },
        );

        if (result is Future) {
          result.whenComplete(() {
            _AutoLinkScope._activeCaptureScopes--;
          });
        } else {
          _AutoLinkScope._activeCaptureScopes--;
        }
      } catch (e) {
        _AutoLinkScope._activeCaptureScopes--;
        rethrow;
      }
    };
  }

  static void _processInstance(
      dynamic instance, List<LxReactive> captured, String key) {
    if (instance is LevitController) {
      for (final reactive in captured) {
        instance.autoDispose(reactive);
      }
    }
  }
}

class _AutoLinkMiddleware extends LevitReactiveMiddleware {
  @override
  void Function(LxReactive)? get onInit => (reactive) {
        // Optimization: Early exit if neither Zone-capture nor Context-owner is active
        final context = Lx.listenerContext;
        final hasOwnerContext = context != null && context.type == 'Owner';

        // 0. Global Check
        if (_AutoLinkScope._activeCaptureScopes == 0 && !hasOwnerContext) {
          return;
        }

        // 1. Capture for auto-dispose (Only if Zone capture is active)
        if (_AutoLinkScope._activeCaptureScopes > 0) {
          final captureList = Zone.current[_AutoLinkScope._captureKey];
          if (captureList is List<LxReactive>) {
            captureList.add(reactive);
          }
        }

        // 2. Set ownerId from context if not already set
        if (reactive.ownerId == null) {
          // Check Zone first (Fast Path for runCaptured)
          final zonedOwnerId =
              Zone.current[_AutoLinkScope._ownerIdKey] as String?;
          if (zonedOwnerId != null) {
            reactive.ownerId = zonedOwnerId;
          } else if (hasOwnerContext) {
            // Check static Context (for Lx.runWithOwner)
            final data = context.data;
            if (data is Map<String, dynamic>) {
              reactive.ownerId = data['ownerId'] as String?;
            }
          }
        }
      };
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
    return _AutoLinkScope._createCaptureHook(builder, scopedKey);
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
    return _AutoLinkScope._createCaptureHookInit(onInit, scopedKey, instance);
  }
}

class _LiveCaptureList extends ListBase<LxReactive> {
  final List<LxReactive> _inner = [];
  final LevitController _controller;

  _LiveCaptureList(this._controller);

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

    // Live Capture Logic
    // We register immediately to avoid race conditions in synchronous tests.
    _controller.autoDispose(element);
  }
}

class _ChainedCaptureList extends ListBase<LxReactive> {
  final List<List<LxReactive>> _targets;

  _ChainedCaptureList(List<LxReactive> inner, List<LxReactive> parent)
      : _targets = [
          inner,
          if (parent is _ChainedCaptureList) ...parent._targets else parent,
        ];

  @override
  int get length => _targets.first.length;

  @override
  set length(int newLength) => _targets.first.length = newLength;

  @override
  LxReactive operator [](int index) => _targets.first[index];

  @override
  void operator []=(int index, LxReactive value) {
    _targets.first[index] = value;
  }

  @override
  void add(LxReactive element) {
    for (final target in _targets) {
      target.add(element);
    }
  }
}

@visibleForTesting
Object get autoLinkCaptureKeyForTesting => _AutoLinkScope.captureKey;

@visibleForTesting
R runCapturedForTesting<R>(
  R Function() builder, [
  String? ownerId,
]) {
  return _AutoLinkScope.runCaptured(builder, (captured, result) {},
      ownerId: ownerId);
}
