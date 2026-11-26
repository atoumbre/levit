import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

class _ItemController extends LevitController {
  final count = 0.lx.named('count');
  final String label;

  _ItemController(this.label);
}

class _CustomAsyncView extends LAsyncView<String> {
  const _CustomAsyncView({super.resolver});

  @override
  Widget buildLoading(BuildContext context) =>
      const Text('custom-loading', textDirection: TextDirection.ltr);

  @override
  Widget buildError(BuildContext context, Object err) =>
      Text('custom-error:$err', textDirection: TextDirection.ltr);

  @override
  Widget buildView(BuildContext context, String controller) =>
      Text('custom-view:$controller', textDirection: TextDirection.ltr);
}

void main() {
  testWidgets(
    'LView and LScopedView honor null from explicit resolver without untagged fallback',
    (tester) async {
      final scope = LevitScope.root('resolver_null');
      scope.put<String>(() => 'untagged');

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LScope(
            configure: (s) => s.put<String>(() => 'scoped-untagged'),
            child: Column(
              children: [
                LView<String>(
                  resolver: (ctx) =>
                      ctx.levit.findOrNull<String>(tag: 'missing'),
                  orElse: (_) => const Text('view-missing'),
                  builder: (_, v) => Text('view-$v'),
                ),
                LScopedView<String>(
                  resolver: (ctx) =>
                      ctx.levit.findOrNull<String>(tag: 'missing'),
                  orElse: (_) => const Text('scoped-missing'),
                  builder: (_, v) => Text('scoped-$v'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('view-missing'), findsOneWidget);
      expect(find.text('scoped-missing'), findsOneWidget);
      await scope.dispose();
    },
  );

  testWidgets(
    'LAsyncView shows loading during reload and handles nullable null values',
    (tester) async {
      final first = Completer<String?>();
      final second = Completer<String?>();
      var currentFuture = first.future;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LAsyncView<String?>(
            args: const [1],
            resolver: (_) => currentFuture,
            loading: (_) => const Text('loading'),
            builder: (_, value) => Text('value:${value ?? "null"}'),
          ),
        ),
      );

      expect(find.text('loading'), findsOneWidget);
      first.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('value:null'), findsOneWidget);

      currentFuture = second.future;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LAsyncView<String?>(
            args: const [2],
            resolver: (_) => currentFuture,
            loading: (_) => const Text('loading'),
            builder: (_, value) => Text('value:${value ?? "null"}'),
          ),
        ),
      );

      expect(find.text('loading'), findsOneWidget);
      second.complete('loaded');
      await tester.pumpAndSettle();
      expect(find.text('value:loaded'), findsOneWidget);
    },
  );

  testWidgets(
    'LAsyncView delegates to subclass buildView, buildLoading, and buildError overrides',
    (tester) async {
      final completer = Completer<String>();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LScope(
            child: _CustomAsyncView(resolver: (_) => completer.future),
          ),
        ),
      );

      expect(find.text('custom-loading'), findsOneWidget);
      completer.complete('ok');
      await tester.pumpAndSettle();
      expect(find.text('custom-view:ok'), findsOneWidget);
    },
  );

  testWidgets(
    'LWatch does not alias a replacement controller reactive onto a disposed one',
    (tester) async {
      Levit.enableAutoLinking();
      addTearDown(Levit.disableAutoLinking);

      final scope = LevitScope.root('watch_replace');
      var controller = scope.put(() => _ItemController('first'));
      controller.count.value = 1;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LWatch(() => Text('${controller.count()}')),
        ),
      );
      expect(find.text('1'), findsOneWidget);

      await scope.delete<_ItemController>();
      controller = scope.put(() => _ItemController('second'));
      controller.count.value = 42;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LWatch(() => Text('${controller.count()}')),
        ),
      );
      expect(find.text('42'), findsOneWidget);

      controller.count.value = 43;
      await tester.pump();
      expect(find.text('43'), findsOneWidget);

      await scope.dispose();
    },
  );

  testWidgets('LWatch keeps rebuilding after deactivation and reparenting', (
    tester,
  ) async {
    final watchKey = GlobalKey();
    final counter = 0.lx;
    final leftSlot = true.lx;

    Widget buildTree(bool left) {
      final watched = LWatch(key: watchKey, () => Text('val:${counter()}'));
      return Directionality(
        textDirection: TextDirection.ltr,
        child: left ? Row(children: [watched]) : Column(children: [watched]),
      );
    }

    await tester.pumpWidget(buildTree(true));
    expect(find.text('val:0'), findsOneWidget);

    await tester.pumpWidget(buildTree(false));
    counter.value = 1;
    await tester.pump();
    expect(find.text('val:1'), findsOneWidget);

    counter.value = 2;
    await tester.pump();
    expect(find.text('val:2'), findsOneWidget);

    await counter.close();
    await leftSlot.close();
  });

  test(
    'LevitScopeLifecycleController preserves cleanup error on replace and retry while closing',
    () async {
      final parent = LevitScope.root('lifecycle_parent');
      final lifecycle = LevitScopeLifecycleController();

      await lifecycle.replace(
        parent: parent,
        name: 's1',
        initialize: (s) {
          s.put<_FailingDisposable>(_FailingDisposable.new);
        },
      );

      await lifecycle.replace(parent: parent, name: 's2', initialize: (_) {});
      expect(lifecycle.error, isA<LevitDisposalException>());

      // Subsequent replace must not hide the cleanup error.
      await lifecycle.replace(parent: parent, name: 's3', initialize: (_) {});
      expect(lifecycle.error, isA<LevitDisposalException>());

      // Closing preserves the error even if retry() is called while closing.
      final closing = lifecycle.close();
      expect(() => lifecycle.retry(), throwsStateError);
      await expectLater(closing, throwsA(isA<LevitDisposalException>()));
      await parent.dispose();
    },
  );
}

class _FailingDisposable implements LevitScopeDisposable {
  @override
  void onInit() {}

  @override
  void didAttachToScope(LevitScope scope, {String? key}) {}

  @override
  FutureOr<void> onClose() {
    throw StateError('cleanup failed');
  }
}
