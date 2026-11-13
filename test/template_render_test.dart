// Renders every template's on-screen document to PNG so the designs can be
// eyeballed without a device. Run on demand:
//   RENDER_TEMPLATES=1 flutter test test/template_render_test.dart
// Files land in build/templates/ (or $TEMPLATES_DIR).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:invonce/data/models.dart';
import 'package:invonce/data/sample_data.dart';
import 'package:invonce/screens/invoice_document.dart';
import 'package:invonce/theme/theme.dart';
import 'package:invonce/theme/typography.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('render every template', (tester) async {
    final outDir = Directory(Platform.environment['TEMPLATES_DIR'] ?? 'build/templates')..createSync(recursive: true);
    tester.view.physicalSize = const Size(780, 2200); // 390×1100 logical at 2×
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.runAsync(Fonts.preload);

    for (final t in InvoiceTemplate.values) {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildDaylitTheme(Brightness.light),
          home: Scaffold(
            body: RepaintBoundary(
              key: key,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: InvoiceDocument(invoice: demoInvoices.first, business: demoBusiness, template: t),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${outDir.path}/${t.id}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
    expect(outDir.listSync().whereType<File>().where((f) => f.path.endsWith('.png')).length, greaterThanOrEqualTo(6));
  }, skip: Platform.environment['RENDER_TEMPLATES'] != '1');
}
