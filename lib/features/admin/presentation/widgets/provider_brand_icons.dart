import 'package:flutter/widgets.dart';

/// ---------------------------------------------------------------------------
/// Provider brand marks
/// ---------------------------------------------------------------------------
/// The model picker used to label each provider group with a generic glyph, so
/// a row said nothing the admin could not read from the name beside it. These
/// are the marks the providers publish: the Groq bolt from the outline in the
/// company's own favicon, the OpenRouter chevron from Simple Icons, and the
/// Gemini spark rebuilt from its four tips and concave edges. Like every other
/// glyph in the panel they are drawn flat in the colour the caller asks for.
class ProviderBrandIcon extends StatelessWidget {
  final String provider;
  final double size;
  final Color color;

  const ProviderBrandIcon({
    super.key,
    required this.provider,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _FilledPathPainter(_brandMarks[provider]!(size), color),
    );
  }
}

final Map<String, Path Function(double size)> _brandMarks = {
  'gemini': _geminiSpark,
  'groq': (size) => _svgPath(_groqBolt, size / 33),
  'openrouter': (size) => _svgPath(_openRouterChevron, size / 24),
};

/// Four tips on the axes, every edge a quadratic that pinches just outside the
/// centre: the official spark puts its control point 1.02 units off centre in a
/// 24-unit box.
Path _geminiSpark(double size) {
  final c = size / 2;
  final k = size * 0.0425;
  return Path()
    ..moveTo(c, size)
    ..quadraticBezierTo(c + k, c + k, size, c)
    ..quadraticBezierTo(c + k, c - k, c, 0)
    ..quadraticBezierTo(c - k, c - k, 0, c)
    ..quadraticBezierTo(c - k, c + k, c, size)
    ..close();
}

const String _groqBolt =
    'm18.445 4.406-9.468 13.74 7.341.665-1.69 9.578 9.469-13.74'
    '-7.342-.664 1.69-9.579Z';

const String _openRouterChevron =
    'M16.778 1.844v1.919q-.569-.026-1.138-.032-.708-.008-1.415.037'
    'c-1.93.126-4.023.728-6.149 2.237-2.911 2.066-2.731 1.95-4.14 2.75'
    '-.396.223-1.342.574-2.185.798-.841.225-1.753.333-1.751.333v4.229'
    's.768.108 1.61.333c.842.224 1.789.575 2.185.799 1.41.798 1.228.683'
    ' 4.14 2.75 2.126 1.509 4.22 2.11 6.148 2.236.88.058 1.716.041'
    ' 2.555.005v1.918l7.222-4.168-7.222-4.17v2.176c-.86.038-1.611.065'
    '-2.278.021-1.364-.09-2.417-.357-3.979-1.465-2.244-1.593-2.866-2.027'
    '-3.68-2.508.889-.518 1.449-.906 3.822-2.59 1.56-1.109 2.614-1.377'
    ' 3.978-1.466.667-.044 1.418-.017 2.278.02v2.176L24 6.014Z';

final _commandPattern = RegExp(r'^[A-Za-z]$');
final _tokenPattern = RegExp(r'[A-Za-z]|[-+]?(?:\d+\.?\d*|\.\d+)');

/// The subset of SVG path data the two marks above use: moveto, lineto, the
/// vertical and horizontal shorthand, cubics with their smooth sibling,
/// quadratics and close. Every length is multiplied by [scale], which keeps
/// relative deltas correct.
Path _svgPath(String data, double scale) {
  final tokens = _tokenPattern
      .allMatches(data)
      .map((m) => m[0]!)
      .toList();

  final path = Path();
  var x = 0.0;
  var y = 0.0;
  var startX = 0.0;
  var startY = 0.0;
  var lastCtrlX = 0.0;
  var lastCtrlY = 0.0;
  var hasCubicControl = false;
  var command = '';
  var index = 0;

  double read() => double.parse(tokens[index++]) * scale;

  while (index < tokens.length) {
    if (_commandPattern.hasMatch(tokens[index])) {
      command = tokens[index++];
    }
    final relative = command == command.toLowerCase();
    final baseX = relative ? x : 0.0;
    final baseY = relative ? y : 0.0;

    switch (command.toUpperCase()) {
      case 'M':
        startX = x = read() + baseX;
        startY = y = read() + baseY;
        path.moveTo(x, y);
        // Bare coordinate pairs after a moveto are line-tos.
        command = relative ? 'l' : 'L';
        hasCubicControl = false;
      case 'L':
        x = read() + baseX;
        y = read() + baseY;
        path.lineTo(x, y);
        hasCubicControl = false;
      case 'V':
        y = read() + baseY;
        path.lineTo(x, y);
        hasCubicControl = false;
      case 'H':
        x = read() + baseX;
        path.lineTo(x, y);
        hasCubicControl = false;
      case 'C':
        final inX = read() + baseX;
        final inY = read() + baseY;
        lastCtrlX = read() + baseX;
        lastCtrlY = read() + baseY;
        x = read() + baseX;
        y = read() + baseY;
        path.cubicTo(inX, inY, lastCtrlX, lastCtrlY, x, y);
        hasCubicControl = true;
      case 'S':
        final inX = hasCubicControl ? 2 * x - lastCtrlX : x;
        final inY = hasCubicControl ? 2 * y - lastCtrlY : y;
        lastCtrlX = read() + baseX;
        lastCtrlY = read() + baseY;
        x = read() + baseX;
        y = read() + baseY;
        path.cubicTo(inX, inY, lastCtrlX, lastCtrlY, x, y);
        hasCubicControl = true;
      case 'Q':
        final controlX = read() + baseX;
        final controlY = read() + baseY;
        x = read() + baseX;
        y = read() + baseY;
        path.quadraticBezierTo(controlX, controlY, x, y);
        hasCubicControl = false;
      case 'Z':
        path.close();
        x = startX;
        y = startY;
        index++;
      default:
        index++;
    }
  }
  return path;
}

class _FilledPathPainter extends CustomPainter {
  final Path path;
  final Color color;

  const _FilledPathPainter(this.path, this.color);

  @override
  void paint(Canvas canvas, Size size) =>
      canvas.drawPath(path, Paint()..color = color);

  @override
  bool shouldRepaint(_FilledPathPainter old) =>
      old.path != path || old.color != color;
}
