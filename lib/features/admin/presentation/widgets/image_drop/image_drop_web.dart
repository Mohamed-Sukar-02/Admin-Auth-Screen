import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Whether this build can receive files dropped from the desktop.
const bool imageDropSupported = true;

/// Watches the whole page for image files dropped by the OS while the caller
/// is alive — Flutter web paints to a canvas, so the document is the only
/// surface that receives these events. Returns the detach callback.
void Function() watchImageDrop({
  required void Function(Uint8List bytes, String name) onImage,
  required void Function(String name) onNonImage,
  required void Function(bool active) onDrag,
}) {
  final document = web.window.document;
  var entered = 0;

  // The browser only delivers `drop` if `dragover` is cancelled, and counts
  // enter/leave pairs so nested elements don't flicker the highlight.
  final onEnter = (web.DragEvent event) {
    event.preventDefault();
    if (entered++ == 0) onDrag(true);
  }.toJS;

  final onLeave = (web.DragEvent event) {
    event.preventDefault();
    if (--entered <= 0) {
      entered = 0;
      onDrag(false);
    }
  }.toJS;

  final onOver = (web.DragEvent event) {
    event.preventDefault();
  }.toJS;

  final onDrop = (web.DragEvent event) {
    event.preventDefault();
    entered = 0;
    onDrag(false);

    final files = event.dataTransfer?.files;
    if (files == null || files.length == 0) return;
    final file = files.item(0);
    if (file == null) return;

    if (!file.type.startsWith('image/')) {
      onNonImage(file.name);
      return;
    }

    file.arrayBuffer().toDart.then((buffer) {
      onImage(buffer.toDart.asUint8List(), file.name);
    });
  }.toJS;

  document.addEventListener('dragenter', onEnter);
  document.addEventListener('dragleave', onLeave);
  document.addEventListener('dragover', onOver);
  document.addEventListener('drop', onDrop);

  return () {
    document.removeEventListener('dragenter', onEnter);
    document.removeEventListener('dragleave', onLeave);
    document.removeEventListener('dragover', onOver);
    document.removeEventListener('drop', onDrop);
  };
}
