import 'package:web/web.dart' as web;

const _widthKey = 'daily-meal.admin-sidebar-width';
const _collapsedKey = 'daily-meal.admin-sidebar-collapsed';

double? readSidebarWidth() =>
    double.tryParse(web.window.localStorage.getItem(_widthKey) ?? '');

void writeSidebarWidth(double width) =>
    web.window.localStorage.setItem(_widthKey, width.toStringAsFixed(0));

bool readSidebarCollapsed() =>
    web.window.localStorage.getItem(_collapsedKey) == 'true';

void writeSidebarCollapsed(bool collapsed) =>
    web.window.localStorage.setItem(_collapsedKey, collapsed.toString());
