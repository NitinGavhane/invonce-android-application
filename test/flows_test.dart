import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:invonce/data/app_store.dart';
import 'package:invonce/data/demo_repository.dart';
import 'package:invonce/data/models.dart';
import 'package:invonce/main.dart';
import 'package:invonce/widgets/sheets.dart';

/// Drives the real app (demo mode) the way a user would.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<AppStore> launch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = AppStore(DemoRepository(), demo: true);
    await store.load();
    await tester.pumpWidget(InvonceApp(store: store));
    await tester.pumpAndSettle();
    return store;
  }

  Future<void> tapFinder(WidgetTester tester, Finder finder) async {
    expect(finder, findsWidgets);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) => tapFinder(tester, find.text(text).first);

  /// Bottom tab bar labels are the last matching text on screen.
  Future<void> tapTab(WidgetTester tester, String label) => tapFinder(tester, find.text(label).last);

  Future<void> tapIcon(WidgetTester tester, IconData icon, {bool last = false}) =>
      tapFinder(tester, last ? find.byIcon(icon).last : find.byIcon(icon).first);

  Future<void> back(WidgetTester tester) => tapIcon(tester, Icons.arrow_back_ios_new_rounded);

  /// The n-th text input inside the open bottom sheet (page search boxes are TextFields too).
  Finder sheetField(int n) =>
      find.descendant(of: find.byType(SheetShell), matching: find.byType(TextField)).at(n);

  Future<void> skipToHome(WidgetTester tester) async {
    await tapText(tester, 'Skip — explore the demo');
    expect(find.text('Northwind Studio'), findsOneWidget);
  }

  testWidgets('welcome → home shows the business and recent invoices', (tester) async {
    await launch(tester);
    expect(find.text('Invoices that get you paid.'), findsOneWidget);
    await skipToHome(tester);
    expect(find.text('Recent invoices'), findsOneWidget);
    expect(find.text('Vela Marketing'), findsWidgets);
  });

  testWidgets('more → legal & privacy → every policy opens; delete account asks first', (tester) async {
    await launch(tester);
    await skipToHome(tester);
    await tapTab(tester, 'More');
    await tapText(tester, 'Legal & privacy');
    for (final title in ['Privacy Policy', 'Terms of Service', 'Subscription & Refund Policy', 'Data & Account Deletion']) {
      await tapText(tester, title);
      expect(find.text(title), findsOneWidget);
      await back(tester);
    }
    await tapText(tester, 'Delete account');
    expect(find.text('Delete your account?'), findsOneWidget);
    await tapText(tester, 'Keep my account');
    expect(find.text('Legal & privacy'), findsOneWidget);
  });

  testWidgets('home avatar → profile menu → business profile', (tester) async {
    await launch(tester);
    await skipToHome(tester);
    await tapText(tester, 'NS'); // the avatar tile
    expect(find.text('Business profile & logo'), findsOneWidget);
    expect(find.text('Tax & currency'), findsOneWidget);
    await tapText(tester, 'Business profile & logo');
    expect(find.text('Business profile'), findsOneWidget);
  });

  testWidgets('clients tab → + → type a name → save → appears in the list', (tester) async {
    final store = await launch(tester);
    await skipToHome(tester);
    await tapTab(tester, 'Clients');
    expect(find.text('Harbor & Co'), findsOneWidget);

    await tapIcon(tester, Icons.add_rounded); // header "+" (the FAB is last)
    expect(find.text('New client'), findsOneWidget);
    await tester.enterText(sheetField(0), 'Orca Labs');
    await tester.enterText(sheetField(1), 'hi@orca.io');
    await tapText(tester, 'Save client');

    expect(store.clients.any((c) => c.name == 'Orca Labs'), isTrue);
    expect(find.text('Orca Labs'), findsOneWidget);
  });

  testWidgets('client row → detail → + Invoice → editor prefilled with that client', (tester) async {
    await launch(tester);
    await skipToHome(tester);
    await tapTab(tester, 'Clients');
    await tapText(tester, 'Harbor & Co');
    expect(find.text('Client'), findsOneWidget);
    expect(find.text('Viewed INV-0012'), findsOneWidget);
    await tapText(tester, 'Invoice');
    expect(find.text('New invoice'), findsOneWidget);
    expect(find.text('Harbor & Co'), findsOneWidget);
  });

  testWidgets('+ → editor → add item → save & preview → mark paid → receipt', (tester) async {
    final store = await launch(tester);
    await skipToHome(tester);
    await tapIcon(tester, Icons.add_rounded, last: true); // the FAB
    expect(find.text('New invoice'), findsOneWidget);
    expect(find.text('INV-0014'), findsOneWidget);

    // No client is pre-selected; pick one from the Bill-to sheet.
    expect(find.text('Choose a client'), findsOneWidget);
    await tapText(tester, 'Choose a client');
    await tapText(tester, 'Harbor & Co');
    expect(find.text('Harbor & Co'), findsOneWidget);

    await tapText(tester, 'Add your first item');
    await tapText(tester, 'Logo design');
    expect(find.text('\$660.00'), findsOneWidget); // 600 + 10% tax

    await tapText(tester, 'Save & preview');
    expect(find.text('Invoice · INV-0014'), findsOneWidget);
    expect(store.invoices.first.number, 'INV-0014');

    await tapText(tester, 'Mark paid');
    expect(find.text('Record payment'), findsOneWidget);
    await tapText(tester, 'Record \$660.00 & mark paid');
    expect(find.text('PAYMENT RECEIVED'), findsOneWidget);
    expect(store.invoices.first.isPaid, isTrue);
  });

  testWidgets('editor → × on Tax removes it; Add brings it back', (tester) async {
    await launch(tester);
    await skipToHome(tester);
    await tapIcon(tester, Icons.add_rounded, last: true);
    await tapText(tester, 'Add your first item');
    await tapText(tester, 'Logo design');
    expect(find.text('Tax (10%)'), findsOneWidget);
    expect(find.text('\$660.00'), findsOneWidget);

    await tapFinder(tester, find.byKey(const Key('remove-tax')));
    expect(find.text('Tax (10%)'), findsNothing);
    expect(find.text('\$600.00'), findsNWidgets(2)); // no tax: subtotal == total
    expect(find.byKey(const Key('remove-tax')), findsNothing);

    // Both Discount and Tax now read "Add"; the Tax line is the later one.
    await tapFinder(tester, find.text('Add').last);
    expect(find.text('Tax rate'), findsOneWidget);
    await tapText(tester, '10% · DEFAULT');
    expect(find.text('Tax (10%)'), findsOneWidget);
    expect(find.text('\$660.00'), findsOneWidget);
  });

  testWidgets('invoices tab filters work', (tester) async {
    await launch(tester);
    await skipToHome(tester);
    await tapTab(tester, 'Invoices');
    await tapText(tester, 'OVERDUE');
    expect(find.text('Juniper Bakery'), findsOneWidget);
    expect(find.text('Vela Marketing'), findsNothing);
  });

  testWidgets('more → every settings screen opens and closes', (tester) async {
    await launch(tester);
    await skipToHome(tester);
    await tapTab(tester, 'More');
    for (final (row, title) in const [
      ('Business profile & logo', 'Business profile'),
      ('Items & services', 'Items & services'),
      ('Payment methods', 'Payment methods'),
      ('Templates', 'Templates'),
      ('Tax & currency', 'Tax & currency'),
      ('Signature & defaults', 'Signature'),
      ('Reports & exports', 'Reports'),
      ('Expenses', 'Expenses'),
    ]) {
      await tapText(tester, row);
      expect(find.text(title), findsWidgets, reason: 'opening $row');
      await back(tester);
    }
  });

  testWidgets('editor → Bill to → New client → saved and selected without leaving the invoice', (tester) async {
    final store = await launch(tester);
    await skipToHome(tester);
    await tapIcon(tester, Icons.add_rounded, last: true);
    await tapText(tester, 'Choose a client');
    await tapText(tester, 'New client');
    expect(find.text('Save client'), findsOneWidget);
    await tester.enterText(sheetField(0), 'Pine Street Dental');
    await tapText(tester, 'Save client');
    expect(store.clients.any((c) => c.name == 'Pine Street Dental'), isTrue);
    expect(find.text('Pine Street Dental'), findsOneWidget); // now shown in Bill to
    expect(find.text('New invoice'), findsOneWidget); // still in the editor
  });

  testWidgets('client detail → edit → name changes everywhere', (tester) async {
    final store = await launch(tester);
    await skipToHome(tester);
    await tapTab(tester, 'Clients');
    await tapText(tester, 'Harbor & Co');
    await tapIcon(tester, Icons.edit_outlined);
    expect(find.text('Edit client'), findsOneWidget);
    await tester.enterText(sheetField(0), 'Harbor & Company');
    await tapText(tester, 'Save changes');
    expect(find.text('Harbor & Company'), findsOneWidget);
    expect(store.invoices.where((i) => i.client.name == 'Harbor & Company').length, 2);
  });

  testWidgets('items → + → new item is saved; expenses → + → new expense is saved', (tester) async {
    final store = await launch(tester);
    await skipToHome(tester);
    await tapTab(tester, 'More');
    await tapText(tester, 'Items & services');
    await tapIcon(tester, Icons.add_rounded);
    await tester.enterText(sheetField(0), 'Photo retouching');
    await tester.enterText(sheetField(1), '85');
    await tapText(tester, 'Save item');
    expect(store.catalog.any((i) => i.name == 'Photo retouching' && i.price == 85), isTrue);
    expect(find.text('Photo retouching'), findsOneWidget);
    await back(tester);

    await tapText(tester, 'Expenses');
    final before = store.totalExpenses;
    await tapIcon(tester, Icons.add_rounded);
    await tester.enterText(sheetField(0), 'Domain renewal');
    await tester.enterText(sheetField(1), '18');
    await tapText(tester, 'Save expense');
    expect(store.totalExpenses, before + 18);
    expect(find.text('Domain renewal'), findsOneWidget);
  });

  testWidgets('record payment → custom amount → partial payment leaves a balance', (tester) async {
    final store = await launch(tester);
    await skipToHome(tester);
    await tapText(tester, 'Vela Marketing'); // INV-0013, $3,080
    await tapText(tester, 'Mark paid');
    await tapText(tester, 'CUSTOM');
    await tester.enterText(sheetField(0), '1000');
    await tapText(tester, 'Use this amount');
    expect(find.text('Record \$1,000.00'), findsOneWidget);
    await tapText(tester, 'Record \$1,000.00');
    expect(find.text('PAYMENT RECEIVED'), findsOneWidget);
    final inv = store.invoices.firstWhere((i) => i.number == 'INV-0013');
    expect(inv.isPaid, isFalse);
    expect(inv.balance, closeTo(2080, 0.001));
  });

  testWidgets('estimate → mark accepted → convert to invoice', (tester) async {
    final store = await launch(tester);
    await skipToHome(tester);
    await tapText(tester, 'Estimate');
    await tapText(tester, 'Atlas Fitness'); // EST-0009, sent
    expect(find.text('Estimate · EST-0009'), findsOneWidget);
    await tapText(tester, 'Mark accepted');
    expect(find.text('Convert to invoice'), findsOneWidget);
    // The confirmation toast must not block the action bar (it used to).
    await tapText(tester, 'Convert to invoice');
    expect(find.text('Invoice · INV-0014'), findsOneWidget);
    expect(store.estimates.firstWhere((e) => e.number == 'EST-0009').status, InvoiceStatus.accepted);
  });

  testWidgets('search narrows invoices and clients', (tester) async {
    await launch(tester);
    await skipToHome(tester);
    await tapTab(tester, 'Invoices');
    await tester.enterText(find.byType(TextField).first, 'juniper');
    await tester.pumpAndSettle();
    expect(find.text('Juniper Bakery'), findsWidgets);
    expect(find.text('Vela Marketing'), findsNothing);

    await tapTab(tester, 'Clients');
    await tester.enterText(find.byType(TextField).first, 'cedar');
    await tester.pumpAndSettle();
    expect(find.text('Cedar & Pine Co'), findsOneWidget);
    expect(find.text('Harbor & Co'), findsNothing);
  });
}
