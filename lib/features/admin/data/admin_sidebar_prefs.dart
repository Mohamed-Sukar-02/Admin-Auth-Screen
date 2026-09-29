import 'admin_sidebar_prefs_io.dart'
    if (dart.library.js_interop) 'admin_sidebar_prefs_web.dart' as platform;

/// Remembers how the admin sidebar was last laid out so a reload does not snap
/// it back to the default width.
double? readSidebarWidth() => platform.readSidebarWidth();

void writeSidebarWidth(double width) => platform.writeSidebarWidth(width);

bool readSidebarCollapsed() => platform.readSidebarCollapsed();

void writeSidebarCollapsed(bool collapsed) =>
    platform.writeSidebarCollapsed(collapsed);
