// Platform gate for receiving image files dropped from the operating system.
//
// Only the web build can see OS drag & drop, so the stub keeps the same API
// on Android/desktop where the file picker button remains the only path.
export 'image_drop_stub.dart'
    if (dart.library.js_interop) 'image_drop_web.dart';
