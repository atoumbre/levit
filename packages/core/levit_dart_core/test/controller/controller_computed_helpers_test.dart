import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

class _DerivedController extends LevitController {
  final firstName = 'Ada'.lx;
  final lastName = 'Lovelace'.lx;
  final query = 'dart'.lx;

  late final fullName = computed(
    () => '${firstName()} ${lastName()}',
    name: 'fullName',
  );
  late final searchResult = asyncComputed(
    () async => 'results:${query()}',
    name: 'searchResult',
  );
}

void main() {
  group('Controller and store computed helpers', () {
    test(
      'tracks dependencies and disposes computed and asyncComputed on close',
      () async {
        final scope = Levit.createScope('derived-controller-test');
        final controller = scope.put(_DerivedController.new);

        expect(controller.fullName(), 'Ada Lovelace');
        expect(controller.fullName.name, 'fullName');

        controller.firstName.value = 'Grace';
        controller.lastName.value = 'Hopper';
        expect(controller.fullName(), 'Grace Hopper');

        expect(await controller.searchResult.wait, 'results:dart');
        controller.query.value = 'levit';
        expect(await controller.searchResult.wait, 'results:levit');

        await scope.dispose();
        expect(controller.fullName.isDisposed, isTrue);
        expect(controller.searchResult.isDisposed, isTrue);
      },
    );

    test(
      'creates owned computed and asyncComputed values via LevitRef',
      () async {
        final baseStore = LevitStore((ref) => ref.own(2.lx));
        final doubledStore = LevitStore((ref) {
          final base = ref.findStore(baseStore);
          return ref.computed(() => base() * 2, name: 'doubled');
        });
        final asyncStore = LevitStore((ref) {
          final doubled = ref.findStore(doubledStore);
          return ref.asyncComputed(() async => doubled() + 1);
        });

        final scope = Levit.createScope('derived-store-test');
        final base = baseStore.findIn(scope);
        final doubled = doubledStore.findIn(scope);
        final asyncValue = asyncStore.findIn(scope);

        expect(doubled(), 4);
        expect(await asyncValue.wait, 5);

        base.value = 5;
        expect(doubled(), 10);
        expect(await asyncValue.wait, 11);

        await scope.dispose();
        expect(doubled.isDisposed, isTrue);
        expect(asyncValue.isDisposed, isTrue);
      },
    );
  });
}
