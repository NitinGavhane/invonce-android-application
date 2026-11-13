// Renders real app screens to PNG for the launch video. Run on demand:
//   RENDER_SHOTS=1 SHOTS_DIR=/path flutter test test/brag_shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:invonce/data/app_store.dart';
import 'package:invonce/data/demo_repository.dart';
import 'package:invonce/data/models.dart';
import 'package:invonce/screens/invoice_editor.dart';
import 'package:invonce/screens/invoice_preview.dart';
import 'package:invonce/screens/invoices.dart';
import 'package:invonce/screens/receipt.dart';
import 'package:invonce/screens/templates.dart';
import 'package:invonce/screens/clients.dart';
import 'package:invonce/screens/reports.dart';
import 'package:invonce/shell.dart';
import 'package:invonce/theme/theme.dart';
import 'package:invonce/theme/typography.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('render brag screenshots', (tester) async {
    final outDir = Directory(Platform.environment['SHOTS_DIR'] ?? 'build/brag_shots')..createSync(recursive: true);
    const ratio = 3.0;
    tester.view.physicalSize = const Size(390 * ratio, 844 * ratio);
    tester.view.devicePixelRatio = ratio;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await Fonts.preload();
      // Widget tests have no icon font; load the SDK's so icons render for real.
      final sdk = File(Platform.resolvedExecutable).parent.parent.parent.parent.parent;
      for (final candidate in [
        File('${sdk.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'),
        File('/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'),
      ]) {
        if (candidate.existsSync()) {
          final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(candidate.readAsBytesSync())));
          await loader.load();
          break;
        }
      }
    });

    final store = AppStore(DemoRepository(), demo: true);
    await store.load();
    final inv = store.invoices.first;
    final paid = store.invoices.firstWhere((i) => i.isPaid);

    Future<void> shot(String name, Widget screen, {Future<void> Function()? act}) async {
      final key = GlobalKey();
      await tester.pumpWidget(AppScope(
        store: store,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildDaylitTheme(Brightness.light),
          home: RepaintBoundary(key: key, child: screen),
        ),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      if (act != null) await act();
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: ratio);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${outDir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    await shot('home', const AppShell());
    await shot('invoices', const InvoicesScreen());
    await shot('clients', const ClientsScreen());
    await shot('reports', const ReportsScreen());
    await shot('editor', InvoiceEditorScreen(client: inv.client, initialItems: inv.items));
    await shot('preview', InvoicePreviewScreen(invoice: inv));
    await shot('preview_bold', InvoicePreviewScreen(invoice: inv, template: InvoiceTemplate.bold));
    await shot('templates', const TemplatesScreen());
    await shot('receipt', ReceiptScreen(invoice: paid, amount: paid.total, method: 'Card', reference: '#4421'));
    expect(outDir.listSync().length, greaterThanOrEqualTo(9));
  }, skip: Platform.environment['RENDER_SHOTS'] != '1');
}
