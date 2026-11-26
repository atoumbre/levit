part of '../kit_library.dart';

/// A mixin for [LevitController] that manages reactive selection state.
///
/// Supports both multi-selection and single-selection modes via
/// [allowMultiSelect]. [selectedItems] is registered via [own] inside
/// [onInit]; subclasses overriding [onInit] must call `super.onInit()`.
///
/// ```dart
/// class InboxController extends LevitController with LevitSelectionMixin<String> {
///   @override
///   bool get allowMultiSelect => true;
///
///   void onRowTap(String messageId) => toggle(messageId);
/// }
/// ```
///
/// {@category Loops, Timers & Selection}
mixin LevitSelectionMixin<T> on LevitController {
  /// The set of currently selected items.
  final selectedItems = LxSet<T>().named('selectedItems');

  /// Whether multiple distinct items can be selected at once.
  ///
  /// Defaults to `true`. Override to `false` for single-selection (radio-button
  /// style). Because [selectedItems] is an [LxSet], duplicate entries of the
  /// same item are always deduplicated.
  bool get allowMultiSelect => true;

  @override
  void onInit() {
    super.onInit();
    own(selectedItems);
  }

  /// Selects an [item].
  ///
  /// If [allowMultiSelect] is false, this clears any previous selection first.
  void select(T item) {
    if (!allowMultiSelect) {
      if (selectedItems.length == 1 && selectedItems.contains(item)) return;
      selectedItems.assignOne(item);
      return;
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
  /// If [allowMultiSelect] is `false`, selects only the last item in [items]
  /// (and leaves the current selection unchanged when [items] is empty).
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

  /// Returns `true` if [item] is selected.
  ///
  /// Reads [selectedItems], so calling this inside a reactive observer tracks
  /// selection changes automatically.
  bool isSelected(T item) => selectedItems.contains(item);

  /// The number of currently selected items.
  ///
  /// Reads [selectedItems], so calling this inside a reactive observer tracks
  /// selection changes automatically.
  int get selectionCount => selectedItems.length;
}
