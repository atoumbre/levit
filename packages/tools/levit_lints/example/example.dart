/// Enable `levit_lints` in your project's root `analysis_options.yaml`:
///
/// ```yaml
/// plugins:
///   levit_lints:
///     path: /absolute/path/to/levit/packages/tools/levit_lints
///     diagnostics:
///       await_levit_lifecycle: true
///       avoid_global_levit_in_widgets: true
///       discarded_levit_future: true
///       must_call_super_levit_lifecycle: true
///       unowned_levit_resource: true
///       avoid_plain_lx_status_fields: true
///       avoid_preconstructed_levit_put: true
/// ```
///
/// Then run `dart analyze --fatal-infos` or `flutter analyze` to enforce
/// ownership and lifecycle diagnostics across your codebase.
void main() {
  // This package is a native Dart analyzer plugin; see README.md for rule details.
}
