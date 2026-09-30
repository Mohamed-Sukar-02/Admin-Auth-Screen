import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const _files = {
  'iphone': 'assets/images/iphone_moc.jpg',
  'android': 'assets/images/android_moc.jpg',
};

Future<_Pix> _decode(String path) async {
  final bytes = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final img = frame.image;
  final data = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  return _Pix(data.buffer.asUint8List(), img.width, img.height);
}

class _Pix {
  final Uint8List b;
  final int w;
  final int h;
  _Pix(this.b, this.w, this.h);
  int lum(int x, int y) {
    final i = (y * w + x) * 4;
    return (b[i] + b[i + 1] + b[i + 2]) ~/ 3;
  }
}

void main() {
  testWidgets('measure', (tester) async {
    for (final e in _files.entries) {
      await tester.runAsync(() async {
        final p = await _decode(e.value);
        final cx = p.w ~/ 2, cy = p.h ~/ 2;
        bool bright(int x, int y) => p.lum(x, y) > 200;

        var sx0 = cx;
        while (sx0 > 0 && bright(sx0 - 1, cy)) {
          sx0--;
        }
        var sx1 = cx;
        while (sx1 < p.w - 1 && bright(sx1 + 1, cy)) {
          sx1++;
        }
        final probe = sx0 + ((sx1 - sx0) * 0.22).round();
        var sy0 = cy;
        while (sy0 > 0 && bright(probe, sy0 - 1)) {
          sy0--;
        }
        var sy1 = cy;
        while (sy1 < p.h - 1 && bright(probe, sy1 + 1)) {
          sy1++;
        }

        // outer edges: first non-white walking in from the canvas edge
        int edgeLeft(int y) {
          for (var x = 0; x < p.w; x++) {
            if (p.lum(x, y) < 245) return x;
          }
          return -1;
        }

        int edgeRight(int y) {
          for (var x = p.w - 1; x >= 0; x--) {
            if (p.lum(x, y) < 245) return x;
          }
          return -1;
        }

        int edgeTop(int x) {
          for (var y = 0; y < p.h; y++) {
            if (p.lum(x, y) < 245) return y;
          }
          return -1;
        }

        int edgeBottom(int x) {
          for (var y = p.h - 1; y >= 0; y--) {
            if (p.lum(x, y) < 245) return y;
          }
          return -1;
        }

        print('=== ${e.key}: canvas ${p.w}x${p.h}');
        print('  SCREEN x:$sx0..$sx1 y:$sy0..$sy1 size=${sx1 - sx0 + 1}x${sy1 - sy0 + 1} '
            'aspect=${((sx1 - sx0 + 1) / (sy1 - sy0 + 1)).toStringAsFixed(4)}');
        print('  outer @centerRow  L=${edgeLeft(cy)} R=${edgeRight(cy)}');
        print('  outer @centerCol  T=${edgeTop(cx)} B=${edgeBottom(cx)}');
        print('  outer @screenColL L=${edgeLeft(sx0 + 3)} R=${edgeRight(sx0 + 3)} '
            'T=${edgeTop(sx0 + 3)} B=${edgeBottom(sx0 + 3)}');

        // Hard-silhouette edges (threshold 200 ignores the soft cast shadow).
        int hardL(int y) {
          for (var x = 0; x < p.w; x++) {
            if (p.lum(x, y) < 200) return x;
          }
          return -1;
        }

        int hardR(int y) {
          for (var x = p.w - 1; x >= 0; x--) {
            if (p.lum(x, y) < 200) return x;
          }
          return -1;
        }

        int hardT(int x) {
          for (var y = 0; y < p.h; y++) {
            if (p.lum(x, y) < 200) return y;
          }
          return -1;
        }

        int hardB(int x) {
          for (var y = p.h - 1; y >= 0; y--) {
            if (p.lum(x, y) < 200) return y;
          }
          return -1;
        }

        var hl = p.w, hr = 0, ht = p.h, hb = 0;
        for (final y in [cy, sy0 + 20, sy1 - 20, (sy0 + sy1) ~/ 2]) {
          hl = [hl, hardL(y)].reduce((a, b) => a < b ? a : b);
          hr = [hr, hardR(y)].reduce((a, b) => a > b ? a : b);
        }
        for (final x in [cx, sx0 + 20, sx1 - 20]) {
          ht = [ht, hardT(x)].reduce((a, b) => a < b ? a : b);
          hb = [hb, hardB(x)].reduce((a, b) => a > b ? a : b);
        }
        print('  HARD silhouette x:$hl..$hr y:$ht..$hb size=${hr - hl + 1}x${hb - ht + 1}');
        print('  HARD bezel insets: L=${sx0 - hl} R=${hr - sx1} T=${sy0 - ht} B=${hb - sy1}');

        // island / camera: dark pixels inside the screen, middle columns only
        final lo = sx0 + ((sx1 - sx0) * 0.30).round();
        final hi = sx0 + ((sx1 - sx0) * 0.70).round();
        var nx0 = sx1, nx1 = sx0, ny0 = sy1, ny1 = sy0, found = false;
        for (var y = sy0; y < sy0 + 70; y++) {
          for (var x = lo; x <= hi; x++) {
            if (p.lum(x, y) < 80) {
              found = true;
              if (x < nx0) nx0 = x;
              if (x > nx1) nx1 = x;
              if (y < ny0) ny0 = y;
              if (y > ny1) ny1 = y;
            }
          }
        }
        if (found) {
          final sw = sx1 - sx0 + 1, sh = sy1 - sy0 + 1;
          print('  NOTCH x:$nx0..$nx1 y:$ny0..$ny1 size=${nx1 - nx0 + 1}x${ny1 - ny0 + 1}');
          print('  notch frac l=${((nx0 - sx0) / sw).toStringAsFixed(4)} '
              't=${((ny0 - sy0) / sh).toStringAsFixed(4)} '
              'w=${((nx1 - nx0 + 1) / sw).toStringAsFixed(4)} '
              'h=${((ny1 - ny0 + 1) / sh).toStringAsFixed(4)}');
        } else {
          print('  NOTCH none');
        }

        // ASCII map of the top-left corner: '#' dark, '+' mid, '.' bright
        final sb = StringBuffer('  TL corner map (rows sy0-6..sy0+30, cols sx0-8..sx0+45):\n');
        for (var y = sy0 - 6; y < sy0 + 31; y++) {
          sb.write('    ${y.toString().padLeft(3)} ');
          for (var x = sx0 - 8; x < sx0 + 46; x++) {
            if (x < 0 || x >= p.w || y < 0 || y >= p.h) {
              sb.write(' ');
              continue;
            }
            final l = p.lum(x, y);
            sb.write(l < 90 ? '#' : (l < 200 ? '+' : (l < 246 ? ':' : '.')));
          }
          sb.write('\n');
        }
        print(sb.toString());
      });
    }
  });
}
