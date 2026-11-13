import 'package:flutter_test/flutter_test.dart';
import 'package:invonce/data/app_store.dart';
import 'package:invonce/data/demo_repository.dart';
import 'package:invonce/data/models.dart';

void main() {
  group('AppStore on the demo repository', () {
    late AppStore store;

    setUp(() async {
      store = AppStore(DemoRepository(), demo: true);
      await store.load();
    });

    test('loads the seed and derives the dashboard numbers', () {
      expect(store.loaded, isTrue);
      expect(store.invoices.length, 13);
      expect(store.estimates.length, 4);
      expect(store.totalOutstanding, 5060);
      expect(store.totalOverdue, 740);
      expect(store.paidLast30, 13400);
      expect(store.totalPaid, 40400);
      expect(store.monthlyRevenue.map((m) => m.$1).toList(), ['May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct']);
      expect(store.monthlyRevenue.map((m) => m.$2).toList(), [6200, 7100, 5400, 8300, 9100, 4300]);
    });

    test('creates an invoice with the next number and tax applied', () async {
      final client = store.clients.firstWhere((c) => c.name == 'Harbor & Co');
      final draft = store.newDraft(client: client, items: const [LineItem(name: 'Logo design', rate: 600)]);
      expect(draft.number, 'INV-0014');
      expect(draft.total, closeTo(660, 0.001)); // 600 + 10% tax

      var notified = 0;
      store.addListener(() => notified++);
      final saved = await store.saveInvoice(draft);

      expect(saved.id, isNot('draft'));
      expect(store.invoices.first.id, saved.id);
      expect(store.invoices.length, 14);
      expect(store.invoicesFor(client).length, 3);
      expect(store.totalOutstanding, closeTo(5060 + 660, 0.001));
      expect(notified, 1);
    });

    test('partial payments reduce the balance; the last one marks it paid', () async {
      final inv = store.invoices.firstWhere((i) => i.number == 'INV-0013'); // $3,080 unpaid
      final partial = await store.recordPayment(inv, amount: 1000, method: 'Bank transfer');
      expect(partial.status, InvoiceStatus.unpaid);
      expect(partial.paid, 1000);
      expect(partial.balance, closeTo(2080, 0.001));
      expect(store.totalOutstanding, closeTo(5060 - 1000, 0.001));

      final full = await store.recordPayment(partial, amount: 2080, method: 'Card');
      expect(full.isPaid, isTrue);
      expect(full.paidOn, isNotNull);
      expect(store.totalOutstanding, closeTo(5060 - 3080, 0.001));
      expect(store.invoices.where((i) => i.id == inv.id).single.isPaid, isTrue);
      expect(store.eventsFor(inv.client).first.title, 'Paid INV-0013');
    });

    test('adds a client with initials and keeps the list sorted', () async {
      final c = await store.addClient(name: 'Orca Labs', email: 'hi@orca.io', phone: '(503) 555-0100');
      expect(c.initials, 'OL');
      expect(store.clients.length, 7);
      expect(store.clients.map((c) => c.name).toList(), [
        'Atlas Fitness', 'Cedar & Pine Co', 'Harbor & Co', 'Juniper Bakery', 'Meadow Interiors', 'Orca Labs', 'Vela Marketing',
      ]);
    });

    test('converting an estimate yields a new invoice draft', () {
      final est = store.estimates.firstWhere((e) => e.status == InvoiceStatus.accepted);
      final draft = store.newDraft(client: est.client, items: est.items);
      expect(draft.isEstimate, isFalse);
      expect(draft.status, InvoiceStatus.unpaid);
      expect(draft.subtotal, est.subtotal);
    });
  });
}
