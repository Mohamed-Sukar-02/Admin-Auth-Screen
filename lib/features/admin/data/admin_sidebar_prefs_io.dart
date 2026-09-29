double? _width;
bool _collapsed = false;

double? readSidebarWidth() => _width;

void writeSidebarWidth(double width) => _width = width;

bool readSidebarCollapsed() => _collapsed;

void writeSidebarCollapsed(bool collapsed) => _collapsed = collapsed;
