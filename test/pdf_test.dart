import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:invonce/data/pdf_service.dart';
import 'package:invonce/data/sample_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('invoice PDF renders with the bundled fonts', () async {
    final inv = demoInvoices.first; // INV-0013, two items, unpaid
    final bytes = await DocumentPdf.invoice(inv, demoBusiness);
    expect(bytes.length, greaterThan(5000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(DocumentPdf.fileName(inv), 'INV-0013.pdf');
    if (Platform.environment['KEEP_PDF'] == '1') File('build/INV-0013.pdf').writeAsBytesSync(bytes);
  });

  test('receipt PDF renders for a paid invoice', () async {
    final inv = demoInvoices.firstWhere((i) => i.isPaid);
    final bytes = await DocumentPdf.receipt(inv, demoBusiness, amount: inv.total, method: 'Card', date: demoToday, reference: '#4421');
    expect(bytes.length, greaterThan(5000));
    expect(DocumentPdf.fileName(inv, receipt: true), startsWith('RCT-'));
    if (Platform.environment['KEEP_PDF'] == '1') File('build/${DocumentPdf.fileName(inv, receipt: true)}').writeAsBytesSync(bytes);
  });
}
