part of '../levit_dart_core.dart';

/// A lightweight bridge passed to [LevitState] builders.
///
/// [LevitRef] provides access to dependency injection and automated resource
/// management within a functional state builder. It acts as a proxy to the
/// [LevitScope] that owns the state.

class LevitRef {
  final _LevitStateInstance _owner;

  final List<void Function()> _onDisposeCallbacks = [];

  LevitRef._(this._owner);

  /// The [LevitScope] that currently owns this state.
  LevitScope get scope => _owner.scope;

  /// Retrieves a dependency of type [S] from the current or parent scope.
  S find<S>({dynamic key, String? tag}) {
    if (key is LevitState) {
      return key.findIn(_owner.scope, tag: tag) as S;
    }
    return _owner.scope.find<S>(tag: tag);
  }

  /// Asynchronously retrieves a dependency of type [S].
  Future<S> findAsync<S>({dynamic key, String? tag}) async {
    if (key is LevitState) {
      final result = await key.findAsyncIn(_owner.scope, tag: tag);
      if (result is Future) return await result as S;
      return result as S;
    }
    return await _owner.scope.findAsync<S>(tag: tag);
  }

  /// Registers a callback to be executed when the state is disposed.
  void onDispose(void Function() callback) {
    _onDisposeCallbacks.add(callback);
  }

  /// Registers an [object] for automatic cleanup when the state is disposed.
  T autoDispose<T>(T object) {
    return _owner.autoDispose(object);
  }

  void _dispose() {
    for (final callback in _onDisposeCallbacks) {
      try {
        callback();
      } catch (e) {
        dev.log('LevitRef: Error executing onDispose callback',
            error: e, name: 'levit_dart');
      }
    }

    _onDisposeCallbacks.clear();
  }
}

/// Deep Dive: Why use LevitState?
///
/// To understand the difference, let's look at a "User Profile" feature that requires an API service.
///
/// ### The Class Way (LevitController)
/// Best for: Complex business logic, long-lived services, or when you need inheritance.
///
/// ```dart
/// class ProfileController extends LevitController {
/// final String userId;
/// ProfileController(this.userId);
///
/// // You must use 'late final' and manually 'autoDispose' every field
/// late final user = autoDispose(LxVar<User?>(null));
/// late final isLoading = autoDispose(false.lx);
///
/// @override
/// void onInit() {
/// super.onInit();
/// fetch();
/// }
///
/// Future<void> fetch() async {
/// isLoading.value = true;
/// final api = scope!.find<Api>(); // Manual scope access
/// user.value = await api.getUser(userId);
/// isLoading.value = false;
/// }
/// }
/// ```
///
/// ### The Functional Way (LevitState)
/// Best for: Data fetching, UI state, composition, and reducing "class fatigue".
///
/// ```dart
/// final profileProvider = (String id) => LevitState((ref) {
/// // Logic is just code! No special lifecycle methods required.
/// final user = ref.autoDispose(LxVar<User?>(null));
/// final isLoading = ref.autoDispose(false.lx);
///
/// // API is injected directly via ref
/// final api = ref.find<Api>();
///
/// void fetch() async {
/// isLoading.value = true;
/// user.value = await api.getUser(id);
/// isLoading.value = false;
/// }
///
/// fetch(); // Just call it
///
/// // Return exactly what the UI needs using a Record
/// return (
/// user: user,
/// isLoading: isLoading,
/// refresh: fetch
/// );
/// });
/// ```
///
/// ### Key Differences:
///
/// 1. **Ergonomics**: `LevitState` removes the need for `late final`, `@override onInit`, and `super.onInit`. You just write a function.
/// 2. **Encapsulation**: `LevitController` uses `_private` fields to hide state. `LevitState` uses the **Return Value** to explicitly define the "Public API" of your state.
/// 3. **Ref Injection**: `LevitRef` is passed into the builder, making it feel very native to Riverpod users. You don't have to look up the `scope` from the controller.
/// 4. **Composition**: `LevitState` builders can easily `watch` or `find` other states, making it easier to create "Derived State" (e.g. a `FilteredList` that depends on a `SearchQuery`).
/// A functional state provider definition.
///
/// [LevitState] acts as a factory for state instances. When found within a scope,
/// it creates a scope-local instance that manages its own lifecycle and value.
class LevitState<T> {
  final T Function(LevitRef ref) _builder;

  /// Creates a new [LevitState] definition.
  LevitState(this._builder);

  /// Creates its scope-local [LxReactive] instance.
  LxReactive createComputed(LevitRef ref, String ownerPath) {
    return LxComputed<T>(
      () => _AutoLinkScope.runCaptured(
        () => _builder(ref),
        (captured, _) {
          for (final reactive in captured) {
            ref.autoDispose(reactive);
          }
        },
        ownerId: ownerPath,
      ),
      name: 'LevitState($ownerPath)',
    );
  }

  late final String _defaultKey = 'ls_value_${getProviderTag(this, null)}';

  /// Extracts the current value from the [computed] instance.
  T getComputedValue(LxReactive computed) {
    return (computed as LxComputed<T>).value;
  }

  /// Creates an asynchronous [LevitState] definition.
  static LevitAsyncState<T> async<T>(Future<T> Function(LevitRef ref) builder) {
    return LevitAsyncState<T>(builder);
  }

  /// Internal helper to resolve this state within a specific [scope].
  T findIn(LevitScope scope, {String? tag}) {
    final instanceKey =
        tag != null ? 'ls_value_${getProviderTag(this, tag)}' : _defaultKey;

    var instance = scope.findOrNull<_LevitStateInstance<T>>(tag: instanceKey);

    if (instance == null) {
      instance = _LevitStateInstance<T>(this);
      scope.put(() => instance!, tag: instanceKey);
    }

    return instance.value;
  }

  /// Internal helper to resolve this state asynchronously within a specific [scope].
  Future<T> findAsyncIn(LevitScope scope, {String? tag}) async {
    final instanceKey =
        tag != null ? 'ls_value_${getProviderTag(this, tag)}' : _defaultKey;

    var instance =
        await scope.findOrNullAsync<_LevitStateInstance<T>>(tag: instanceKey);

    if (instance == null) {
      instance = _LevitStateInstance<T>(this);
      scope.put(() => instance!, tag: instanceKey);
    }

    return instance.value;
  }

  /// Internal helper to delete this state from a specific [scope].
  bool deleteIn(LevitScope scope, {String? tag, bool force = false}) {
    final instanceKey =
        tag != null ? 'ls_value_${getProviderTag(this, tag)}' : _defaultKey;
    return scope.delete<_LevitStateInstance<T>>(tag: instanceKey, force: force);
  }

  /// Internal helper to check if this state is registered in a specific [scope].
  bool isRegisteredIn(LevitScope scope, {String? tag}) {
    final instanceKey =
        tag != null ? 'ls_value_${getProviderTag(this, tag)}' : _defaultKey;
    return scope.isRegistered<_LevitStateInstance<T>>(tag: instanceKey);
  }

  /// Internal helper to check if this state is instantiated in a specific [scope].
  bool isInstantiatedIn(LevitScope scope, {String? tag}) {
    final instanceKey =
        tag != null ? 'ls_value_${getProviderTag(this, tag)}' : _defaultKey;
    return scope.isInstantiated<_LevitStateInstance<T>>(tag: instanceKey);
  }

  @override
  String toString() => 'LevitState<$T>(id: $hashCode)';
}

/// A specialized [LevitState] for asynchronous initialization.
class LevitAsyncState<T> extends LevitState<Future<T>> {
  LevitAsyncState(super.builder);

  @override
  LxAsyncComputed<T> createComputed(LevitRef ref, String ownerPath) {
    return LxAsyncComputed<T>(
      () => _AutoLinkScope.runCaptured(
        () => _builder(ref),
        (captured, _) {
          for (final reactive in captured) {
            ref.autoDispose(reactive);
          }
        },
        ownerId: ownerPath,
      ),
      name: 'LevitState($ownerPath)',
    );
  }

  @override
  Future<T> getComputedValue(LxReactive computed) {
    return (computed as LxAsyncComputed<T>).wait;
  }
}

/// The actual holder of a [LevitState] value within a [LevitScope].
class _LevitStateInstance<T> implements LevitScopeDisposable {
  final LevitState<T> definition;
  late LevitScope _scope;
  String? _registrationKey;
  final List<dynamic> _disposables = [];
  late final LevitRef _ref = LevitRef._(this);
  LxReactive? _computed;
  String? _cachedOwnerPath;

  _LevitStateInstance(this.definition);

  static void _emptyListener() {}

  T get value {
    if (_computed == null) {
      _computed = definition.createComputed(_ref, ownerPath);
      // Add a listener to keep it active and memorized in the scope
      _computed!.addListener(_emptyListener);
    }

    return definition.getComputedValue(_computed!);
  }

  Future<dynamic> get wrappedValue {
    if (_computed is LxAsyncComputed) {
      return (_computed as LxAsyncComputed).wait;
    }
    final val = value;
    if (val is Future) return val;
    return Future.value(val);
  }

  LevitScope get scope => _scope;

  String get ownerPath =>
      _cachedOwnerPath ??= '${_scope.id}:${_registrationKey ?? '?'}';

  /// Registers an [object] for automatic cleanup when the state is disposed.
  S autoDispose<S>(S object) {
    _disposables.add(object);

    // Auto-linking: If the reactive object doesn't have an ownerId, adopt it.
    if (object is LxReactive) {
      if (object.ownerId == null) {
        object.ownerId = ownerPath;
      }
    }

    return object;
  }

  @override
  void onInit() {}

  @override
  void didAttachToScope(LevitScope scope, {String? key}) {
    _scope = scope;
    _registrationKey = key;
    _cachedOwnerPath = null; // Reset in case it was accessed before attach
    final path = ownerPath;

    for (final item in _disposables) {
      if (item is LxReactive) {
        if (item.ownerId != path) {
          item.ownerId = path;
          try {
            item.refresh();
          } catch (_) {}
        }
      }
    }
  }

  @override
  void onClose() {
    _computed?.close();
    _ref._dispose();

    for (final disposable in _disposables) {
      _levitDisposeItem(disposable);
    }
    _disposables.clear();
  }
}

/// Helper to generate a unique tag for a functional provider instance.
String getProviderTag(LevitState provider, String? tag) {
  if (tag != null) return tag;
  return 'lxp_${provider.hashCode}';
}

/// Internal helper to reuse LevitController's cleanup logic without inheritance.
// Replaced by top-level _levitDisposeItem

/// Ergonomic extensions for [LevitState] functional providers.

extension LevitStateExtension<T> on LevitState<T> {
  /// Resolves the current value of this provider from the active [LevitScope].

  T find({String? tag}) => Levit.find<T>(key: this, tag: tag);

  /// Asynchronously resolves the value of this provider.

  Future<T> findAsync({String? tag}) => Levit.findAsync<T>(key: this, tag: tag);

  /// Removes this provider instance from the active [LevitScope].

  bool delete({String? tag, bool force = false}) =>
      Levit.delete(key: this, tag: tag, force: force);
}

/// Extensions for [LevitAsyncState] to unwrap futures.

extension LevitAsyncStateExtension<T> on LevitAsyncState<T> {
  /// Asynchronously resolves the value of this provider, flattening the [Future].

  Future<T> findAsync({String? tag}) async {
    return await find(tag: tag);
  }
}
