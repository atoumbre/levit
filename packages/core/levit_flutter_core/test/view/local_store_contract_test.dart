import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  for (final scoped in [false, true]) {
    for (final async in [false, true]) {
      for (final localOnly in [false, true]) {
        testWidgets(
          'store view scoped=$scoped async=$async localOnly=$localOnly',
          (tester) async {
            final store = LevitStore((ref) => ref.own(0.lx));
            final asyncStore = LevitStore.async((ref) async => ref.own(0.lx));
            late LevitScope parent;
            late LxVar<int> shared;
            late LxVar<int> local;
            final root = LevitScope.root();
            shared = async ? await asyncStore.findIn(root) : store.findIn(root);
            shared.value = 42;
            // The widget-owned parent inherits the externally managed test scope.
            Widget view() {
              Widget builder(BuildContext context, LxVar<int> value) {
                local = value;
                return Text('${value.value}');
              }

              if (async) {
                final asyncView = LAsyncView.store(
                  asyncStore,
                  localOnly: localOnly,
                  builder: builder,
                );
                return scoped ? LScope(child: asyncView) : asyncView;
              }
              return scoped
                  ? LScopedView.store(
                      store,
                      localOnly: localOnly,
                      builder: builder,
                    )
                  : LView.store(store, localOnly: localOnly, builder: builder);
            }

            await root.run(() async {
              await tester.pumpWidget(
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: LScope(
                    configure: (scope) => parent = scope,
                    child: view(),
                  ),
                ),
              );
              await tester.pumpAndSettle();
            });
            expect(find.text(localOnly ? '0' : '42'), findsOneWidget);
            expect(identical(local, shared), !localOnly);
            await tester.pumpWidget(const SizedBox.shrink());
            await parent.dispose();
            expect(local.isDisposed, localOnly);
            expect(shared.isDisposed, isFalse);
            await root.dispose();
          },
        );
      }
    }
  }
}
