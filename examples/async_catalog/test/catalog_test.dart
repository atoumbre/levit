import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:levit_example_async_catalog/catalog.dart';

void main() {
  test(
    'search resets pagination and cache refresh preserves handle identity',
    () async {
      final controller = CatalogController(
        repository: CatalogRepository(latency: Duration.zero),
      );
      final first = await controller.queries.fetch(controller.key.value);
      expect(first.items.first.id, 0);
      expect(first.hasMore, isTrue);
      controller.nextPage();
      expect(
        (await controller.queries.fetch(controller.key.value)).items.first.id,
        6,
      );
      controller.search('Package 24');
      expect(controller.key.value.page, 0);
      final handle = controller.queries.entry(controller.key.value);
      expect(
        (await controller.queries.fetch(controller.key.value)).items.single.id,
        23,
      );
      await controller.refresh();
      expect(controller.queries.entry(controller.key.value), same(handle));
      await controller.onClose();
    },
  );

  test(
    'optimistic edits publish immediately, rollback on failure and persist on success',
    () async {
      final repository = _SaveGateRepository();
      final controller = CatalogController(repository: repository);
      final item = (await controller.queries.fetch(
        controller.key.value,
      )).items.first;
      controller.failNextSave.value = true;
      final failed = controller.toggleFavorite(item);
      expect(controller.isFavorite(item), isTrue);
      expect(controller.saving.contains(item.id), isTrue);
      repository.release.complete();
      await failed;
      expect(controller.isFavorite(item), isFalse);
      expect(controller.message.value, contains('restored'));
      await controller.toggleFavorite(item);
      expect(controller.isFavorite(item), isTrue);
      await controller.refresh();
      expect(
        (await controller.queries.fetch(
          controller.key.value,
        )).items.first.favorite,
        isTrue,
      );
      await controller.onClose();
      expect(repository.closed, isTrue);
    },
  );

  test(
    'route closure drains query cancellation before closing the repository',
    () async {
      final repository = _ClosingRepository();
      final controller = CatalogController(repository: repository);
      controller.queries.entry(controller.key.value);
      await repository.started.future;
      final close = controller.onClose();
      await repository.cancelled.future;
      expect(repository.closed, isFalse);
      repository.release.complete();
      await close;
      expect(repository.closed, isTrue);
    },
  );
}

class _SaveGateRepository extends CatalogRepository {
  _SaveGateRepository() : super(latency: Duration.zero);
  final release = Completer<void>();
  @override
  Future<void> saveFavorite(
    int id,
    bool value,
    LevitTaskContext context, {
    required bool fail,
  }) async {
    await release.future;
    await super.saveFavorite(id, value, context, fail: fail);
  }
}

class _ClosingRepository extends CatalogRepository {
  final started = Completer<void>();
  final cancelled = Completer<void>();
  final release = Completer<void>();
  @override
  Future<CatalogPage> search(CatalogKey key, LevitTaskContext context) async {
    started.complete();
    try {
      await context.cancelled;
      context.throwIfCancelled();
      return CatalogPage([], false);
    } finally {
      cancelled.complete();
      await release.future;
      expect(closed, isFalse);
    }
  }
}
