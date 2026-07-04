part of '../../levit_dart.dart';

class _TaskCacheHit<T> {
  final T result;

  const _TaskCacheHit(this.result);
}

Future<_TaskCacheHit<T>?> _readCachedTaskResult<T>({
  required LevitTaskCacheProvider cacheProvider,
  required String taskId,
  required TaskCachePolicy<T>? cachePolicy,
}) async {
  if (cachePolicy == null) return null;

  final cacheKey = cachePolicy.key ?? taskId;
  final cachedJson = await cacheProvider.read(cacheKey);
  if (cachedJson == null) return null;

  final expiresAt =
      DateTime.fromMillisecondsSinceEpoch(cachedJson['expiresAt'] as int);
  if (DateTime.now().isAfter(expiresAt)) {
    await cacheProvider.delete(cacheKey);
    return null;
  }

  try {
    final data = cachedJson['data'] as Map<String, dynamic>;
    return _TaskCacheHit(cachePolicy.fromJson(data));
  } catch (_) {
    await cacheProvider.delete(cacheKey);
    return null;
  }
}

Future<void> _writeCachedTaskResult<T>({
  required LevitTaskCacheProvider cacheProvider,
  required String taskId,
  required TaskCachePolicy<T>? cachePolicy,
  required T result,
}) async {
  if (cachePolicy == null) return;

  final cacheKey = cachePolicy.key ?? taskId;
  await cacheProvider.write(cacheKey, {
    'expiresAt': DateTime.now().add(cachePolicy.ttl).millisecondsSinceEpoch,
    'data': cachePolicy.toJson(result),
  });
}
