// Generates the app icon for every platform.
//
//   dart run tool/make_icon.dart
//
// The icon is the chop grid: rows are slices, columns are steps, and because
// the grid is monophonic there is exactly one lit cell per column. That last
// part is the whole point of the mark. A dense grid of lit pads is what a pad
// instrument looks like, and this is not one; a scatter of single cells is what
// a tracker looks like, and this is one.
//
// Near black ground, acid green on the slices, orange where the kick lands, the
// unlit grid faintly behind. Nothing else fits in 40 pixels, and nothing else
// would say what this app is.
//
// Drawn in code rather than exported from a design tool for the same reason the
// breaks and the kits are synthesised: it is reproducible, it is in the repo,
// and changing it is a diff rather than a binary.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// junglEngine's palette, straight from lib/theme.dart.
const _background = (0x0A, 0x0C, 0x0A);
const _surface = (0x1F, 0x25, 0x1F);
const _accent = (0xC8, 0xFF, 0x3C);
const _kick = (0xFF, 0x9E, 0x3C);

/// The grid is five steps by five slices, and monophonic: one lit cell per
/// column, and this is which slice each step plays.
///
/// Not the diagonal, which would be the break played straight and would read as
/// a loading spinner. This is a rearrangement: down, up, down further, and the
/// kick landing twice.
const _slicePerStep = [3, 0, 4, 1, 2];

/// Which steps are the kick, in orange. Step one and the middle: a break with
/// its weight in the right places.
const _kickSteps = [0, 3];

/// Steps and slices per side.
const _side = 5;

void main() {
  // iOS, at every size the appiconset asks for.
  const iosSizes = {
    'Icon-App-20x20@1x.png': 20,
    'Icon-App-20x20@2x.png': 40,
    'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29,
    'Icon-App-29x29@2x.png': 58,
    'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40,
    'Icon-App-40x40@2x.png': 80,
    'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120,
    'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76,
    'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
  };
  iosSizes.forEach((name, size) {
    _write('ios/Runner/Assets.xcassets/AppIcon.appiconset/$name', size);
  });

  const macSizes = {
    'app_icon_16.png': 16,
    'app_icon_32.png': 32,
    'app_icon_64.png': 64,
    'app_icon_128.png': 128,
    'app_icon_256.png': 256,
    'app_icon_512.png': 512,
    'app_icon_1024.png': 1024,
  };
  macSizes.forEach((name, size) {
    _write('macos/Runner/Assets.xcassets/AppIcon.appiconset/$name', size);
  });

  // Android launcher icons, plus the adaptive foreground and background the
  // launcher composes for itself on 26 and up.
  const androidSizes = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };
  androidSizes.forEach((density, size) {
    _write('android/app/src/main/res/mipmap-$density/ic_launcher.png', size);
    // An adaptive icon is masked to whatever shape the launcher wants and the
    // outer third can be cropped, so the foreground is drawn inset.
    _write(
      'android/app/src/main/res/mipmap-$density/ic_launcher_foreground.png',
      (size * 108 / 48).round(),
      adaptive: true,
    );
  });
  _writeAdaptiveXml();

  stdout.writeln('junglengine: icons written.');
}

/// Draws the icon at [size] and writes it as a PNG.
///
/// [adaptive] draws the grid smaller and on a transparent ground, for the
/// foreground layer of an Android adaptive icon.
void _write(String path, int size, {bool adaptive = false}) {
  final pixels = _draw(size, adaptive: adaptive);
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(_encodePng(pixels, size, size));
}

/// RGBA, row major.
Uint8List _draw(int size, {required bool adaptive}) {
  final pixels = Uint8List(size * size * 4);

  void fill(int x0, int y0, int x1, int y1, (int, int, int) colour, int alpha) {
    for (var y = y0.clamp(0, size); y < y1.clamp(0, size); y++) {
      for (var x = x0.clamp(0, size); x < x1.clamp(0, size); x++) {
        final at = (y * size + x) * 4;
        pixels[at] = colour.$1;
        pixels[at + 1] = colour.$2;
        pixels[at + 2] = colour.$3;
        pixels[at + 3] = alpha;
      }
    }
  }

  // The ground. Transparent on the adaptive foreground, because the launcher
  // draws the background layer underneath it.
  if (!adaptive) fill(0, 0, size, size, _background, 255);

  // The adaptive foreground is inset further, because a launcher may crop the
  // outer third of it into a circle.
  final margin = (size * (adaptive ? 0.27 : 0.15)).round();
  final field = size - margin * 2;
  final cell = field / _side;
  // A gap of about a fifth of a cell, so the grid reads as cells rather than as
  // a solid block. On a 16 pixel icon a cell is three pixels across, and
  // insisting on a whole pixel of gap there would eat the cell instead.
  final gap = cell < 4 ? cell * 0.2 : (cell * 0.18).clamp(1.0, cell / 3);

  // Below about 32 pixels the unlit grid stops being a grid and starts being
  // noise, so it is drawn only where it can be seen.
  final showsEmpty = size >= 32;

  for (var step = 0; step < _side; step++) {
    for (var slice = 0; slice < _side; slice++) {
      final lit = _slicePerStep[step] == slice;
      if (!lit && !showsEmpty) continue;

      final x0 = (margin + step * cell).round();
      final y0 = (margin + slice * cell).round();
      final x1 = (margin + (step + 1) * cell - gap).round();
      final y1 = (margin + (slice + 1) * cell - gap).round();

      final colour = !lit
          ? _surface
          : (_kickSteps.contains(step) ? _kick : _accent);
      // The unlit grid is barely there on the adaptive foreground: there is no
      // dark ground behind it to sit against.
      final alpha = lit ? 255 : (adaptive ? 70 : 255);
      fill(
        x0,
        y0,
        x1 < x0 + 1 ? x0 + 1 : x1,
        y1 < y0 + 1 ? y0 + 1 : y1,
        colour,
        alpha,
      );
    }
  }

  return pixels;
}

/// The background layer of the Android adaptive icon, and the XML that names
/// both layers.
void _writeAdaptiveXml() {
  const colours = '''
<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by tool/make_icon.dart. -->
<resources>
    <color name="ic_launcher_background">#0A0C0A</color>
</resources>
''';
  const adaptive = '''
<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by tool/make_icon.dart. -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
''';
  _writeText(
    'android/app/src/main/res/values/ic_launcher_background.xml',
    colours,
  );
  _writeText(
    'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
    adaptive,
  );
}

void _writeText(String path, String contents) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
}

// --- PNG ---------------------------------------------------------------------

/// Writes 8 bit RGBA PNG.
///
/// Hand rolled rather than pulled in as a dependency: the app does not need an
/// image library, and this is one chunk layout and a CRC. See the PNG spec,
/// which is short.
Uint8List _encodePng(Uint8List rgba, int width, int height) {
  // Every scanline is prefixed with its filter type. Zero, none: the icon is
  // flat colour and compresses fine without help.
  final raw = Uint8List(height * (1 + width * 4));
  for (var y = 0; y < height; y++) {
    final at = y * (1 + width * 4);
    raw[at] = 0;
    raw.setRange(at + 1, at + 1 + width * 4, rgba, y * width * 4);
  }

  final header = Uint8List(13);
  final view = ByteData.sublistView(header);
  view.setUint32(0, width);
  view.setUint32(4, height);
  header[8] = 8; // Bit depth.
  header[9] = 6; // Colour type: RGBA.
  header[10] = 0; // Deflate.
  header[11] = 0; // Adaptive filtering.
  header[12] = 0; // No interlace.

  final out = BytesBuilder()
    ..add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    ..add(_chunk('IHDR', header))
    ..add(_chunk('IDAT', Uint8List.fromList(ZLibEncoder().convert(raw))))
    ..add(_chunk('IEND', Uint8List(0)));
  return out.toBytes();
}

Uint8List _chunk(String type, Uint8List body) {
  final out = Uint8List(12 + body.length);
  final view = ByteData.sublistView(out);
  view.setUint32(0, body.length);
  out.setRange(4, 8, ascii.encode(type));
  out.setRange(8, 8 + body.length, body);
  view.setUint32(8 + body.length, _crc32(out.sublist(4, 8 + body.length)));
  return out;
}

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc = _crcTable[(crc ^ byte) & 0xFF] ^ (crc >> 8);
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
