import 'models.dart';
import 'repository.dart';
import 'sample_data.dart';

/// In-memory data source used when no Supabase project is configured.
/// Mutations persist for the lifetime of the app process.
class DemoRepository implements InvonceRepository {
  final List<Client> _clients = List.of(demoClients);
  final List<CatalogItem> _items = List.of(demoCatalog);
  final List<Invoice> _documents = [...demoInvoices, ...demoEstimates];
  final List<Expense> _expenses = List.of(demoExpenses);
  final Map<String, List<Activity>> _events = {
    for (final e in demoActivity.entries) e.key: List.of(e.value),
  };
  Business _business = demoBusiness;

  @override
  Future<Snapshot> load() async {
    return Snapshot(
      business: _business,
      clients: List.unmodifiable(_clients),
      items: List.unmodifiable(_items),
      documents: List.unmodifiable(_documents),
      expenses: List.unmodifiable(_expenses),
      events: {for (final e in _events.entries) e.key: List.unmodifiable(e.value)},
    );
  }

  @override
  Future<Invoice> createInvoice(Invoice draft) async {
    final n = _documents.length + 1;
    final saved = draft.copyWith(id: 'local-$n', payToken: 'demo${n.toString().padLeft(4, '0')}');
    _documents.insert(0, saved);
    _log(saved, 'created');
    return saved;
  }

  @override
  Future<Invoice> recordPayment(
    Invoice invoice, {
    required double amount,
    required String method,
    String? reference,
    String? note,
  }) async {
    final paid = invoice.paid + amount;
    final settled = paid >= invoice.total - 0.005;
    final updated = invoice.copyWith(
      paid: paid,
      status: settled ? InvoiceStatus.paid : invoice.status,
      paidOn: settled ? demoToday : invoice.paidOn,
    );
    _replace(updated);
    if (settled) _log(updated, 'paid');
    return updated;
  }

  @override
  Future<Invoice> updateStatus(Invoice invoice, InvoiceStatus status) async {
    final updated = invoice.copyWith(status: status);
    _replace(updated);
    if (status == InvoiceStatus.accepted) _log(updated, 'accepted');
    if (status == InvoiceStatus.sent) _log(updated, 'sent');
    return updated;
  }

  @override
  Future<Client> createClient({
    required String name,
    required String email,
    required String phone,
    String address = '',
  }) async {
    final id = 'local-c${_clients.length + 1}';
    final client = Client(
      id: id,
      name: name,
      initials: initialsOf(name),
      email: email,
      phone: phone,
      address: address,
      color: colorFor(id),
    );
    _clients
      ..add(client)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return client;
  }

  @override
  Future<Client> updateClient(Client client) async {
    final i = _clients.indexWhere((c) => c.id == client.id);
    if (i >= 0) _clients[i] = client;
    for (var d = 0; d < _documents.length; d++) {
      if (_documents[d].client.id == client.id) _documents[d] = _documents[d].copyWith(client: client);
    }
    return client;
  }

  @override
  Future<CatalogItem> createItem({
    required String name,
    required String kind,
    required String unit,
    double? price,
    String? priceLabel,
  }) async {
    final item = CatalogItem(name: name, kind: kind, unit: unit, price: price, priceLabel: priceLabel, icon: iconForItem(name, kind));
    _items.add(item);
    return item;
  }

  @override
  Future<Expense> createExpense({
    required String name,
    required String category,
    required double amount,
    required DateTime date,
  }) async {
    final e = Expense(name: name, category: category, date: date, amount: amount, icon: iconForExpense(category), hasReceipt: false);
    _expenses.insert(0, e);
    return e;
  }

  @override
  Future<Business> updateBusiness(Business business) async => _business = business;

  @override
  Future<void> logEvent(Invoice invoice, String type) async => _log(invoice, type);

  @override
  Future<void> deleteAccount() async {
    // Demo data lives only in memory; nothing to delete.
  }

  // ─── Online payments (simulated) ──────────────────────────────────────────
  // First call creates the account; the next status check "verifies" it.

  @override
  Future<PaymentsStatus> connectPayments({RazorpayOnboarding? razorpay}) async {
    final provider = _business.provider;
    final id = provider == 'razorpay' ? 'acc_demo_route' : 'acct_demo_express';
    _business = _business.copyWith(paymentProvider: provider, paymentAccountId: id, paymentsEnabled: false);
    return PaymentsStatus(
      provider: provider,
      status: provider == 'razorpay' ? 'under_review' : 'onboarding',
      enabled: false,
      accountId: id,
      onboardingUrl: provider == 'stripe' ? 'https://connect.stripe.com/setup/e/demo' : null,
    );
  }

  @override
  Future<PaymentsStatus> paymentsStatus() async {
    if (!_business.hasPaymentAccount) {
      return PaymentsStatus(provider: _business.provider, status: 'not_connected', enabled: false);
    }
    _business = _business.copyWith(paymentsEnabled: true);
    return PaymentsStatus(provider: _business.provider, status: 'active', enabled: true, accountId: _business.paymentAccountId);
  }

  @override
  Future<OnlineSummary> onlineSummary() async {
    // Three of the sample invoices were "paid online".
    final online = _documents.where((d) => d.isPaid && const {'INV-0011', 'INV-0009', 'INV-0008'}.contains(d.number)).toList();
    final collected = online.fold<double>(0, (s, i) => s + i.total);
    return OnlineSummary(
      payments: online.length,
      collected: collected,
      platformFees: _business.platformFeeOn(collected),
      lastPaidAt: online.map((i) => i.paidOn).whereType<DateTime>().fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a),
    );
  }

  void _replace(Invoice updated) {
    final i = _documents.indexWhere((d) => d.id == updated.id);
    if (i >= 0) {
      _documents[i] = updated;
    } else {
      _documents.insert(0, updated);
    }
  }

  void _log(Invoice invoice, String type) {
    final title = switch (type) {
      'sent' => 'Sent ${invoice.number} by email',
      'viewed' => 'Viewed ${invoice.number}',
      'paid' => 'Paid ${invoice.number}',
      'accepted' => '${invoice.number} accepted',
      _ => 'Created ${invoice.number}',
    };
    _events
        .putIfAbsent(invoice.client.id, () => [])
        .insert(0, Activity(icon: iconForEvent(type), title: title, when: DateTime.now()));
  }
}
