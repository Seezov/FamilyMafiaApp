// Run with: flutter test test/generate_icon_test.dart
// Outputs:  assets/app_icon.png  (1024 × 1024)
// Then run: dart run flutter_launcher_icons

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:path_drawing/path_drawing.dart';

// ── SVG path data from android/…/drawable/ic_launcher_foreground.xml ─────────
// Viewport: 338 × 401
// Group transform: scaleX=0.3877307  scaleY=0.46
//                  translateX=103.47352  translateY=108.27

const _fill1 =
    'M336.3,17.96H205.3C193.3,17.96 170.96,39 170.8,63.46'
    'C181.27,59.18 187.93,57.58 201.8,56.96H309.3'
    'C328.65,46.49 337.09,39.33 336.3,17.96Z';

const _fill2 =
    'M170.8,172.96C146.9,185.7 132.75,201.5 124.25,216'
    'C120.93,222.5 117.44,232.5 116.86,242.5'
    'C114.76,279.21 114.44,294.75 116.8,331.46'
    'C136.81,337.96 170.8,304.96 170.8,286.96V262.46'
    'C170.8,262.46 164.49,255.95 170.8,262.31V172.96Z';

const _fill3 =
    'M299.81,127.96C295.48,149.72 289.76,159.03 269.31,166.96'
    'C286.66,170.58 293.97,178.86 299.81,205.46V127.96Z';

const _outline =
    'M336.3,17.96C336.3,17.96 217.3,17.96 205.3,17.96'
    'M336.3,17.96C337.09,39.33 328.65,46.49 309.3,56.96H201.8'
    'C187.93,57.58 181.27,59.18 170.8,63.46'
    'M336.3,17.96H205.3'
    'M205.3,17.96C193.3,17.96 170.96,39 170.8,63.46'
    'M170.8,63.46V172.96'
    'M170.8,63.46C135.61,82.3 122.51,99.67 116.8,148.96'
    'C116.8,148.96 119.65,102.92 116.8,42.5'
    'C113.94,-17.92 29.5,1 13.49,22'
    'C-2.51,43 -1.01,64 7.49,81.5'
    'C16,99 124.25,216 124.25,216'
    'M170.8,172.96C146.9,185.7 132.75,201.5 124.25,216'
    'M170.8,172.96C181.21,167.55 188,167.5 197.81,166.96'
    'C207.62,166.42 269.31,166.96 269.31,166.96'
    'M170.8,172.96V262.31'
    'M124.25,216C120.93,222.5 117.44,232.5 116.86,242.5'
    'C114.76,279.21 114.44,294.75 116.8,331.46'
    'M170.8,262.46C170.8,262.46 170.8,268.96 170.8,286.96'
    'M170.8,262.46V286.96'
    'M170.8,262.46C170.8,262.46 164.49,255.95 170.8,262.31'
    'M170.8,262.46V262.31'
    'M170.8,286.96C170.8,304.96 136.81,337.96 116.8,331.46'
    'M116.8,331.46C131.48,467.13 274.96,368.17 213.31,305.46'
    'C187.09,278.78 175.48,267.02 170.8,262.31'
    'M269.31,166.96C289.76,159.03 295.48,149.72 299.81,127.96'
    'V205.46C293.97,178.86 286.66,170.58 269.31,166.96Z';

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  test('generate 1024×1024 app icon PNG', () async {
    const w = 1024.0;
    const h = 1024.0;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, const ui.Rect.fromLTWH(0, 0, w, h));

    // ── Background: dark navy ─────────────────────────────────────────────
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, w, h),
      ui.Paint()..color = const ui.Color(0xFF16213E),
    );

    // ── Foreground: scale viewport (338×401) → canvas (1024×1024) ─────────
    // then apply the VectorDrawable group transform in viewport space
    canvas.save();
    canvas.scale(w / 338, h / 401);          // viewport → canvas
    canvas.translate(103.47352, 108.27);      // group translateX/Y
    canvas.scale(0.3877307, 0.46);            // group scaleX/Y

    final fillPaint = ui.Paint()
      ..color = const ui.Color(0xFFFFFFFF)
      ..style = ui.PaintingStyle.fill;

    final strokePaint = ui.Paint()
      ..color = const ui.Color(0xFFFFFFFF)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = ui.StrokeCap.round
      ..strokeJoin = ui.StrokeJoin.round;

    canvas.drawPath(parseSvgPathData(_fill1), fillPaint);
    canvas.drawPath(parseSvgPathData(_fill2), fillPaint);
    canvas.drawPath(parseSvgPathData(_fill3), fillPaint);
    canvas.drawPath(parseSvgPathData(_outline), strokePaint);

    canvas.restore();

    // ── Save as PNG ───────────────────────────────────────────────────────
    final picture = recorder.endRecording();
    final image = await picture.toImage(w.toInt(), h.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final file = File('assets/app_icon.png');
    await file.writeAsBytes(bytes);

    expect(await file.exists(), isTrue);
    // ignore: avoid_print
    print('✓ Saved ${bytes.length ~/ 1024} KB → ${file.absolute.path}');
  });
}
