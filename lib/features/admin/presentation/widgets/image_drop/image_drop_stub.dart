import 'dart:typed_data';

/// Whether this build can receive files dropped from the desktop.
const bool imageDropSupported = false;

/// No-op where drag & drop from the OS is unavailable; see
/// [imageDropSupported]. Returns the (empty) detach callback.
void Function() watchImageDrop({
  required void Function(Uint8List bytes, String name) onImage,
  required void Function(String name) onNonImage,
  required void Function(bool active) onDrag,
}) => () {};
