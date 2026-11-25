import 'dart:async';
import 'package:levit_flutter/levit_flutter.dart';

typedef CatalogKey = ({String search, int page});

class CatalogItem {
  const CatalogItem(this.id, this.title, {this.favorite = false});
  final int id;
  final String title;
  final bool favorite;
  CatalogItem withFavorite(bool value) =>
      CatalogItem(id, title, favorite: value);
}

class CatalogPage {
  CatalogPage(Iterable<CatalogItem> items, this.hasMore)
    : items = List.unmodifiable(items);
  final List<CatalogItem> items;
  final bool hasMore;
}

/// Demo repository. A real HTTP adapter would use the same cancellation context.
class CatalogRepository implements LevitDisposable {
  CatalogRepository({this.latency = const Duration(milliseconds: 250)});
  final Duration latency;
  bool closed = false;
  final _items = List.generate(
    24,
    (id) => CatalogItem(id, 'Package ${id + 1}'),
  );

  Future<void> _wait(LevitTaskContext context) async {
    if (closed) throw StateError('Repository closed');
    final elapsed = Completer<void>();
    final timer = Timer(latency, elapsed.complete);
    try {
      await Future.any([elapsed.future, context.cancelled]);
      context.throwIfCancelled();
    } finally {
      timer.cancel();
    }
  }

  Future<CatalogPage> search(CatalogKey key, LevitTaskContext context) async {
    await _wait(context);
    final matches = _items
        .where(
          (item) => item.title.toLowerCase().contains(key.search.toLowerCase()),
        )
        .toList();
    const size = 6;
    return CatalogPage(
      matches.skip(key.page * size).take(size),
      matches.length > (key.page + 1) * size,
    );
  }

  Future<void> saveFavorite(
    int id,
    bool value,
    LevitTaskContext context, {
    required bool fail,
  }) async {
    await _wait(context);
    if (fail) throw StateError('Save rejected. The favorite was restored.');
    _items[id] = _items[id].withFavorite(value);
  }

  @override
  Future<void> dispose() async {
    closed = true;
  }
}

/// The route owns this controller; its tasks drain before the repository closes.
class CatalogController extends LevitController with LevitTasksMixin {
  CatalogController({CatalogRepository? repository}) {
    _repository = own(repository ?? CatalogRepository());
    own(key);
    own(favorites);
    own(saving);
    own(message);
    own(failNextSave);
    queries = own(
      LevitAsyncMap<CatalogKey, CatalogPage>(
        _repository.search,
        engine: tasksEngine,
        name: 'catalog',
        maxInactiveEntries: 16,
        gracePeriod: const Duration(seconds: 5),
      ),
    );
  }
  late final CatalogRepository _repository;
  late final LevitAsyncMap<CatalogKey, CatalogPage> queries;
  final key = LxVar<CatalogKey>((search: '', page: 0));
  final favorites = <int, bool>{}.lx;
  final saving = <int>{}.lx;
  final message = LxVar<String?>(null);
  final failNextSave = false.lx;

  void search(String text) => key.value = (search: text.trim(), page: 0);
  void nextPage() =>
      key.value = (search: key.value.search, page: key.value.page + 1);
  void previousPage() {
    if (key.value.page > 0) {
      key.value = (search: key.value.search, page: key.value.page - 1);
    }
  }

  bool isFavorite(CatalogItem item) => favorites[item.id] ?? item.favorite;

  Future<void> refresh() async {
    try {
      await queries.refresh(key.value);
    } on LevitTaskCancelledException {
      /* Route cleanup. */
    } catch (_) {
      /* Error is exposed by the query's status builder. */
    }
  }

  /// One in-flight edit per item. Failed saves restore exactly the previous
  /// application overlay; query producers remain read-only to the mutation.
  Future<void> toggleFavorite(CatalogItem item) async {
    if (saving.contains(item.id) || isClosed) return;
    final before = favorites[item.id];
    final after = !isFavorite(item);
    final fail = failNextSave.value;
    Levit.batch(() {
      favorites[item.id] = after;
      saving.add(item.id);
      message.value = null;
      failNextSave.value = false;
    });
    try {
      await runTask(
        (context) =>
            _repository.saveFavorite(item.id, after, context, fail: fail),
        id: 'save:${item.id}',
      );
    } catch (error) {
      if (!isClosed) {
        Levit.batch(() {
          if (before == null) {
            favorites.remove(item.id);
          } else {
            favorites[item.id] = before;
          }
          message.value = error.toString();
        });
      }
    } finally {
      if (!isClosed) saving.remove(item.id);
    }
  }
}
