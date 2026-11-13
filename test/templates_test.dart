// Every template must render on screen and as a PDF, and the choice made in
// More → Templates must drive both.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:invonce/data/app_store.dart';
import 'package:invonce/data/demo_repository.dart';
import 'package:invonce/data/models.dart';
import 'package:invonce/data/pdf_service.dart';
import 'package:invonce/data/sample_data.dart';
import 'package:invonce/main.dart';
import 'package:invonce/screens/invoice_document.dart';
import 'package:invonce/screens/invoice_preview.dart';
import 'package:invonce/screens/templates.dart';
import 'package:invonce/theme/theme.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('template ids round-trip and unknown ids fall back to Daylit', () {
    for (final t in InvoiceTemplate.values) {
      expect(InvoiceTemplate.fromId(t.id), t);
    }
    expect(InvoiceTemplate.fromId(null), InvoiceTemplate.daylit);
    expect(InvoiceTemplate.fromId('neon'), InvoiceTemplate.daylit);
    expect(InvoiceTemplate.values.map((t) => t.id).toSet().length, InvoiceTemplate.values.length);
  });

  group('PDF', () {
    for (final t in InvoiceTemplate.values) {
      test('${t.label} renders an invoice, an estimate and a paid invoice', () async {
        final business = demoBusiness.copyWith(template: t);
        for (final inv in [
          demoInvoices.first,
          demoEstimates.first,
          demoInvoices.firstWhere((i) => i.isPaid),
        ]) {
          final bytes = await DocumentPdf.invoice(inv, business, payLink: 'https://invonce.app/pay/demo0001');
          expect(bytes.length, greaterThan(5000), reason: '${t.id} ${inv.number}');
          expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
          if (Platform.environment['KEEP_PDF'] == '1') {
            Directory('build/templates').createSync(recursive: true);
            File('build/templates/${t.id}-${inv.number}.pdf').writeAsBytesSync(bytes);
          }
        }
      });
    }
  });

  group('on screen', () {
    for (final t in InvoiceTemplate.values) {
      testWidgets('${t.label} lays out on a phone without overflowing', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final inv = demoInvoices.first;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildDaylitTheme(Brightness.light),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: InvoiceDocument(invoice: inv, business: demoBusiness, template: t),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: t.id);
        expect(find.text(inv.client.name), findsOneWidget);
        // Ledger prints the bare sequence ("INVOICE NO. 0013"); the rest print "INV-0013".
        expect(find.textContaining(inv.number.replaceFirst(RegExp(r'^[A-Z]+-'), '')), findsWidgets);
        expect(find.text(demoBusiness.name), findsOneWidget);
      });
    }
  });

  testWidgets('choosing a template saves it and the preview uses it', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = AppStore(DemoRepository(), demo: true);
    await store.load();
    expect(store.business.template, InvoiceTemplate.daylit);

    await tester.pumpWidget(AppScope(
      store: store,
      child: MaterialApp(theme: buildDaylitTheme(Brightness.light), home: const TemplatesScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('IN USE'), findsOneWidget); // Pill upper-cases its label

    await tester.tap(find.text('Bold'));
    await tester.pumpAndSettle();
    expect(store.business.template, InvoiceTemplate.bold);
    expect(find.text('Bold is now your template'), findsOneWidget);
    expect(find.text('Preview Bold with my invoice'), findsOneWidget);

    // The Classic filter chip hides Bold but still shows the two classic designs.
    await tester.tap(find.text('CLASSIC').first); // chips upper-case their labels
    await tester.pumpAndSettle();
    expect(find.text('Ledger'), findsOneWidget);
    expect(find.text('Bold'), findsNothing);

    // Preview opens the first document in the saved template.
    await tester.tap(find.text('Preview Bold with my invoice'));
    await tester.pumpAndSettle();
    expect(find.byType(InvoicePreviewScreen), findsOneWidget);
    final doc = tester.widget<InvoiceDocument>(find.byType(InvoiceDocument));
    expect(doc.template, InvoiceTemplate.bold);
    expect(find.text(store.documents.first.client.name), findsOneWidget);
  });

  testWidgets('the whole app previews an invoice in the saved template', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = AppStore(DemoRepository(), demo: true);
    await store.load();
    await store.setTemplate(InvoiceTemplate.ledger);

    await tester.pumpWidget(AppScope(
      store: store,
      child: MaterialApp(
        theme: buildDaylitTheme(Brightness.light),
        home: InvoicePreviewScreen(invoice: store.invoices.first),
      ),
    ));
    await tester.pumpAndSettle();
    final doc = tester.widget<InvoiceDocument>(find.byType(InvoiceDocument));
    expect(doc.template, InvoiceTemplate.ledger);
    expect(find.textContaining('INVOICE NO.'), findsOneWidget);
    expect(find.byType(InvonceApp), findsNothing);
  });
}
