// Renders the app icon to assets/icon/icon.png (1024×1024) with the real
// brand font. Run on demand:  flutter test test/icon_render_test.dart
//
// It is skipped in normal `flutter test` runs unless RENDER_ICON=1.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invonce/theme/tokens.dart';
import 'package:invonce/widgets/widgets.dart';

void main() {
  testWidgets('render app icon', (tester) async {
    const family = 'HankenIcon';
    final fontFile = File('assets/google_fonts/HankenGrotesk-ExtraBold.ttf');
    expect(fontFile.existsSync(), isTrue, reason: 'font file missing');

    await tester.runAsync(() async {
      final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(fontFile.readAsBytesSync())));
      await loader.load();
    });

    const size = 1024.0;
    tester.view.physicalSize = const Size(size, size);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Future<void> render(String path, {required Color background, required double markSize}) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: key,
            child: Container(
              width: size,
              height: size,
              color: background,
              alignment: Alignment.center,
              child: ReceiptMark(size: markSize, fontFamily: family),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('assets/icon').createSync(recursive: true);
        File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
      });
      expect(File(path).lengthSync(), greaterThan(5000), reason: path);
    }

    // App Store / legacy launcher: wine tile, mark at ~56% of the tile (design board).
    await render('assets/icon/icon.png', background: Palette.wine, markSize: size * 1.12);
    // Android adaptive foreground: transparent, mark kept inside the 66% safe zone.
    await render('assets/icon/icon_foreground.png', background: Colors.transparent, markSize: size * 0.74);
  }, skip: Platform.environment['RENDER_ICON'] != '1');
}
