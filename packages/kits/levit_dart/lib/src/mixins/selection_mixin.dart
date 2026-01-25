import 'package:levit_dart_core/levit_dart_core.dart';

/// A mixin for [LevitController] that manages selection state.
///
/// It supports both single and multi-selection modes via [allowMultiSelect].
mixin LevitSelectionMixin<T> on LevitController {
  /// The set of currently selected items.
  final selectedItems = LxSet<T>().named('selectedItems');

  /// Whether specific items can be selected multiple times is controlled by the Set nature.
  /// Whether multiple *different* items can be selected is controlled by [allowMultiSelect].

  /// Whether multiple items can be selected at once.
  ///
  /// Defaults to `true`. Override to `false` for single-selection (radio button style).
  bool get allowMultiSelect => true;

  @override
  void onInit() {
    super.onInit();
    autoDispose(selectedItems);
  }

  /// Selects an [item].
  ///
  /// If [allowMultiSelect] is false, this clears any previous selection first.
  void select(T item) {
    if (!allowMultiSelect) {
      selectedItems.clear();
    }
    selectedItems.add(item);
  }

  /// Deselects an [item].
  void deselect(T item) {
    selectedItems.remove(item);
  }

  /// Toggles the selection state of an [item].
  void toggle(T item) {
    if (selectedItems.contains(item)) {
      deselect(item);
    } else {
      select(item);
    }
  }

  /// Selects all [items].
  ///
  /// If [allowMultiSelect] is false, this selects only the last item in the iterable.
  void selectAll(Iterable<T> items) {
    if (!allowMultiSelect) {
      if (items.isNotEmpty) {
        select(items.last);
      }
    } else {
      selectedItems.addAll(items);
    }
  }

  /// Clears the selection.
  void clearSelection() {
    selectedItems.clear();
  }

  /// Returns true if [item] is selected.
  bool isSelected(T item) => selectedItems.contains(item);

  /// Returns the number of selected items.
  int get selectionCount => selectedItems.length;
}
