import 'package:flutter/material.dart';

import 'config.dart';
import 'format.dart';
import 'models.dart';
import 'pricing.dart';
import 'repository.dart';
import 'sample_data.dart';

/// Single source of truth for the UI. Loads a [Snapshot] from the repository,
/// exposes the lists plus every derived number the screens show, and applies
/// mutations after the repository commits them (then listeners rebuild).
class AppStore extends ChangeNotifier {
  AppStore(this.repo, {required this.demo});

  final InvonceRepository repo;

  /// True when running on in-memory sample data (no Supabase configured).
  final bool demo;

  bool loading = false;
  bool loaded = false;
  Object? error;

  Business business = const Business(name: '', initials: '', email: '', phone: '', address: '', website: '');
  List<Client> clients = const [];
  List<CatalogItem> catalog = const [];
  List<Invoice> documents = const [];
  List<Expense> expenses = const [];
  Map<String, List<Activity>> _events = const {};

  DateTime get today => demo ? demoToday : DateTime.now();

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final s = await repo.load();
      business = s.business;
      currencyCode = business.currency;
      clients = s.clients;
      catalog = s.items;
      documents = s.documents;
      expenses = s.expenses;
      _events = s.events;
      loaded = true;
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void reset() {
    loaded = false;
    error = null;
    clients = const [];
    catalog = const [];
    documents = const [];
    expenses = const [];
    _events = const {};
    notifyListeners();
  }

  // ─── Derived data ─────────────────────────────────────────────────────────

  List<Invoice> get invoices => documents.where((d) => !d.isEstimate).toList();
  List<Invoice> get estimates => documents.where((d) => d.isEstimate).toList();

  List<Invoice> invoicesFor(Client c) => invoices.where((i) => i.client.id == c.id).toList();
  double outstandingFor(Client c) => invoicesFor(c).where((i) => i.isOpen).fold(0, (s, i) => s + i.balance);
  List<Activity> eventsFor(Client c) => _events[c.id] ?? const [];

  double get totalOutstanding => invoices.where((i) => i.isOpen).fold(0, (s, i) => s + i.balance);
  double get totalOverdue =>
      invoices.where((i) => i.status == InvoiceStatus.overdue).fold(0, (s, i) => s + i.balance);
  double get totalPaid => invoices.where((i) => i.isPaid).fold(0, (s, i) => s + i.total);
  double get paidLast30 => invoices
      .where((i) => i.isPaid && i.paidOn != null && today.difference(i.paidOn!).inDays <= 30)
      .fold(0, (s, i) => s + i.total);
  double get totalExpenses => expenses.fold(0, (s, e) => s + e.amount);

  /// Paid revenue per month for the last six months, oldest first.
  List<(String, double)> get monthlyRevenue {
    final out = <(String, double)>[];
    for (var k = 5; k >= 0; k--) {
      final m = DateTime(today.year, today.month - k, 1);
      final sum = invoices
          .where((i) => i.isPaid && i.paidOn != null && i.paidOn!.year == m.year && i.paidOn!.month == m.month)
          .fold<double>(0, (s, i) => s + i.total);
      out.add((fmtMonth(m), sum));
    }
    return out;
  }

  String nextNumber({bool estimate = false}) {
    final prefix = estimate ? 'EST' : 'INV';
    final count = documents.where((d) => d.isEstimate == estimate).length;
    return '$prefix-${(count + 1).toString().padLeft(4, '0')}';
  }

  Invoice newDraft({required Client client, List<LineItem> items = const [], bool estimate = false}) {
    return Invoice(
      id: 'draft',
      number: nextNumber(estimate: estimate),
      client: client,
      items: items,
      issued: today,
      due: today.add(Duration(days: business.dueInDays)),
      status: estimate ? InvoiceStatus.draft : InvoiceStatus.unpaid,
      taxRate: business.taxRate,
      isEstimate: estimate,
    );
  }

  // ─── Mutations ────────────────────────────────────────────────────────────

  Future<Invoice> saveInvoice(Invoice draft) async {
    final saved = await repo.createInvoice(draft);
    documents = [saved, ...documents];
    notifyListeners();
    return saved;
  }

  Future<Invoice> recordPayment(
    Invoice invoice, {
    required double amount,
    required String method,
    String? reference,
    String? note,
  }) async {
    var target = invoice;
    if (invoice.id == 'draft') target = await saveInvoice(invoice);
    final updated = await repo.recordPayment(target, amount: amount, method: method, reference: reference, note: note);
    if (documents.any((d) => d.id == updated.id)) {
      documents = [for (final d in documents) d.id == updated.id ? updated : d];
    } else {
      documents = [updated, ...documents];
    }
    if (updated.isPaid && !target.isPaid) _addEvent(updated.client.id, 'paid', 'Paid ${updated.number}');
    notifyListeners();
    return updated;
  }

  void _addEvent(String clientId, String type, String title) {
    final list = List<Activity>.of(_events[clientId] ?? const []);
    list.insert(0, Activity(icon: iconForEvent(type), title: title, when: DateTime.now()));
    _events = {..._events, clientId: list};
  }

  Future<Client> addClient({required String name, required String email, required String phone, String address = ''}) async {
    final c = await repo.createClient(name: name, email: email, phone: phone, address: address);
    clients = [...clients, c]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    notifyListeners();
    return c;
  }

  Future<Client> updateClient(Client c) async {
    final saved = await repo.updateClient(c);
    clients = [for (final x in clients) x.id == saved.id ? saved : x]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    documents = [for (final d in documents) d.client.id == saved.id ? d.copyWith(client: saved) : d];
    notifyListeners();
    return saved;
  }

  Future<CatalogItem> addItem({
    required String name,
    required String kind,
    required String unit,
    double? price,
    String? priceLabel,
  }) async {
    final item = await repo.createItem(name: name, kind: kind, unit: unit, price: price, priceLabel: priceLabel);
    catalog = [...catalog, item]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    notifyListeners();
    return item;
  }

  Future<Expense> addExpense({
    required String name,
    required String category,
    required double amount,
    required DateTime date,
  }) async {
    final e = await repo.createExpense(name: name, category: category, amount: amount, date: date);
    expenses = [e, ...expenses];
    notifyListeners();
    return e;
  }

  Future<Invoice> setStatus(Invoice invoice, InvoiceStatus status) async {
    final updated = await repo.updateStatus(invoice, status);
    documents = [for (final d in documents) d.id == updated.id ? updated : d];
    if (status == InvoiceStatus.accepted) _addEvent(updated.client.id, 'accepted', '${updated.number} accepted');
    notifyListeners();
    return updated;
  }

  Future<void> updateBusiness(Business b) async {
    business = await repo.updateBusiness(b);
    currencyCode = business.currency;
    notifyListeners();
  }

  /// Switches the document design for every invoice, estimate and receipt.
  Future<void> setTemplate(InvoiceTemplate t) => updateBusiness(business.copyWith(template: t));

  // ─── Online payments ──────────────────────────────────────────────────────

  /// Latest collected-online totals; null until [refreshOnline] has run.
  OnlineSummary? online;

  /// Regional Pro price for the business's country.
  ProPrice get proPrice => proPriceFor(business.country);

  /// Public "view & pay" link for a saved document ('' for unsaved drafts).
  String payLinkFor(Invoice inv) {
    if (inv.id == 'draft') return '';
    final token = inv.payToken ?? inv.id;
    final base = demo ? 'https://invonce.app/pay' : AppConfig.payBaseUrl;
    return '$base/$token';
  }

  Future<PaymentsStatus> connectPayments({RazorpayOnboarding? razorpay}) async {
    final s = await repo.connectPayments(razorpay: razorpay);
    business = business.copyWith(
      paymentProvider: s.provider,
      paymentAccountId: s.accountId ?? business.paymentAccountId,
      paymentsEnabled: s.enabled,
    );
    notifyListeners();
    return s;
  }

  Future<PaymentsStatus> refreshPaymentsStatus() async {
    final s = await repo.paymentsStatus();
    business = business.copyWith(paymentProvider: s.provider, paymentsEnabled: s.enabled);
    notifyListeners();
    return s;
  }

  Future<OnlineSummary> refreshOnline() async {
    online = await repo.onlineSummary();
    notifyListeners();
    return online!;
  }

  Future<void> deleteAccount() async {
    await repo.deleteAccount();
    if (!demo) reset();
  }

  Future<void> markSent(Invoice invoice) async {
    if (invoice.id == 'draft') return;
    await repo.logEvent(invoice, 'sent');
    _addEvent(invoice.client.id, 'sent', 'Sent ${invoice.number} by email');
    notifyListeners();
  }
}

/// Puts the store in the tree. `AppScope.watch(context)` rebuilds on change;
/// `AppScope.read(context)` does not.
class AppScope extends InheritedNotifier<AppStore> {
  const AppScope({super.key, required AppStore store, required super.child}) : super(notifier: store);

  static AppStore watch(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
