import 'dart:js_interop';

@JS('window.open')
external JSAny? _open(String url, String target);
void downloadExport(String url) {
  _open(url, '_blank');
}
