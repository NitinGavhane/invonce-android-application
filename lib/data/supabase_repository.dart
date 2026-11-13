import 'package:supabase_flutter/supabase_flutter.dart' hide Snapshot;

import 'models.dart';
import 'repository.dart';

/// Postgres-backed data source. Row-level security scopes every query to the
/// signed-in user's business, so no business id is ever passed from the app.
class SupabaseRepository implements InvonceRepository {
  SupabaseClient get _db => Supabase.instance.client;

  static const _invoiceSelect = '*, invoice_items(*), payments(amount), clients(*)';

  // ─── Loading ──────────────────────────────────────────────────────────────

  @override
  Future<Snapshot> load() async {
    final biz = await _db.from('businesses').select().limit(1).maybeSingle();
    if (biz == null) {
      throw StateError('No business row for this account yet — sign out and back in.');
    }

    final results = await Future.wait<List<Map<String, dynamic>>>([
      _db.from('clients').select().order('name'),
      _db.from('items').select().order('name'),
      _db.from('invoices').select(_invoiceSelect).order('issued_on', ascending: false).order('number', ascending: false),
      _db.from('expenses').select().order('spent_on', ascending: false),
      _db.from('invoice_events').select('type, at, invoices!inner(client_id, number)').order('at', ascending: false).limit(200),
    ]);

    final events = <String, List<Activity>>{};
    for (final row in results[4]) {
      final inv = row['invoices'] as Map<String, dynamic>;
      final type = row['type'] as String;
      final number = inv['number'] as String;
      final title = switch (type) {
        'sent' => 'Sent $number by email',
        'viewed' => 'Viewed $number',
        'paid' => 'Paid $number',
        'reminded' => 'Reminder sent for $number',
        'accepted' => '$number accepted',
        _ => 'Created $number',
      };
      events.putIfAbsent(inv['client_id'] as String, () => []).add(
            Activity(icon: iconForEvent(type), title: title, when: _ts(row['at']) ?? DateTime.now()),
          );
    }

    return Snapshot(
      business: _business(biz),
      clients: results[0].map(_client).toList(),
      items: results[1].map(_item).toList(),
      documents: results[2].map(_invoice).toList(),
      expenses: results[3].map(_expense).toList(),
      events: events,
    );
  }

  // ─── Mutations ────────────────────────────────────────────────────────────

  @override
  Future<Invoice> createInvoice(Invoice draft) async {
    final id = await _db.rpc('create_invoice', params: {
      'p': {
        'client_id': draft.client.id,
        'kind': draft.isEstimate ? 'estimate' : 'invoice',
        'status': draft.status.name,
        'issued_on': _day(draft.issued),
        'due_on': _day(draft.due),
        'discount': draft.discount,
        'tax_rate': draft.taxRate,
        'items': [
          for (final it in draft.items) {'name': it.name, 'qty': it.qty, 'rate': it.rate},
        ],
      },
    });
    return _fetchInvoice(id as String);
  }

  @override
  Future<Invoice> recordPayment(
    Invoice invoice, {
    required double amount,
    required String method,
    String? reference,
    String? note,
  }) async {
    await _db.rpc('record_payment', params: {
      'p_invoice': invoice.id,
      'p_amount': amount,
      'p_method': _methodCode(method),
      'p_reference': reference,
      'p_note': note,
    });
    return _fetchInvoice(invoice.id);
  }

  @override
  Future<Client> createClient({
    required String name,
    required String email,
    required String phone,
    String address = '',
  }) async {
    final row = await _db
        .from('clients')
        .insert({
          'business_id': await _businessId(),
          'name': name,
          'email': email,
          'phone': phone,
          'address': address,
        })
        .select()
        .single();
    return _client(row);
  }

  @override
  Future<Client> updateClient(Client client) async {
    final row = await _db
        .from('clients')
        .update({
          'name': client.name,
          'email': client.email,
          'phone': client.phone,
          'address': client.address,
        })
        .eq('id', client.id)
        .select()
        .single();
    return _client(row);
  }

  @override
  Future<CatalogItem> createItem({
    required String name,
    required String kind,
    required String unit,
    double? price,
    String? priceLabel,
  }) async {
    final row = await _db
        .from('items')
        .insert({
          'business_id': await _businessId(),
          'name': name,
          'kind': kind.toLowerCase(),
          'unit': unit,
          'price': price,
          'price_label': priceLabel,
        })
        .select()
        .single();
    return _item(row);
  }

  @override
  Future<Expense> createExpense({
    required String name,
    required String category,
    required double amount,
    required DateTime date,
  }) async {
    final row = await _db
        .from('expenses')
        .insert({
          'business_id': await _businessId(),
          'name': name,
          'category': category,
          'amount': amount,
          'spent_on': _day(date),
        })
        .select()
        .single();
    return _expense(row);
  }

  @override
  Future<Invoice> updateStatus(Invoice invoice, InvoiceStatus status) async {
    await _db.from('invoices').update({'status': status.name}).eq('id', invoice.id);
    if (status == InvoiceStatus.accepted || status == InvoiceStatus.sent) {
      await logEvent(invoice, status.name);
    }
    return _fetchInvoice(invoice.id);
  }

  @override
  Future<Business> updateBusiness(Business business) async {
    final row = await _db
        .from('businesses')
        .update({
          'name': business.name,
          'email': business.email,
          'phone': business.phone,
          'address': business.address,
          'website': business.website,
          'tax_id': business.taxId,
          'tax_rate': business.taxRate,
          'currency': business.currency,
          'due_days': business.dueInDays,
          'country': business.country,
          'template': business.template.id,
        })
        .eq('id', await _businessId())
        .select()
        .single();
    return _business(row);
  }

  @override
  Future<void> logEvent(Invoice invoice, String type) async {
    await _db.from('invoice_events').insert({
      'business_id': await _businessId(),
      'invoice_id': invoice.id,
      'type': type,
    });
  }

  @override
  Future<void> deleteAccount() async {
    await _db.rpc('delete_my_account');
    _cachedBusinessId = null;
    // The user no longer exists server-side, so a global sign-out would be
    // rejected (403) and mask the successful deletion. Drop the local session only.
    try {
      await _db.auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      // Session is gone either way; the auth stream sends the app back to sign-in.
    }
  }

  // ─── Online payments (Edge Functions) ─────────────────────────────────────

  @override
  Future<PaymentsStatus> connectPayments({RazorpayOnboarding? razorpay}) async {
    final res = await _db.functions.invoke(
      'connect-onboard',
      body: razorpay == null ? <String, dynamic>{} : {'razorpay': razorpay.toJson()},
    );
    return _status(res.data as Map<String, dynamic>);
  }

  @override
  Future<PaymentsStatus> paymentsStatus() async {
    final res = await _db.functions.invoke('connect-onboard', body: {'check': true});
    return _status(res.data as Map<String, dynamic>);
  }

  @override
  Future<OnlineSummary> onlineSummary() async {
    final row = await _db.from('online_payment_summary').select().limit(1).maybeSingle();
    if (row == null) return OnlineSummary.empty;
    return OnlineSummary(
      payments: (row['payments'] as num?)?.toInt() ?? 0,
      collected: _num(row['collected']),
      platformFees: _num(row['platform_fees']),
      lastPaidAt: _ts(row['last_paid_at']),
    );
  }

  static PaymentsStatus _status(Map<String, dynamic> d) {
    final url = d['url'] as String?;
    final enabled = d['enabled'] == true;
    return PaymentsStatus(
      provider: (d['provider'] as String?) ?? 'stripe',
      status: (d['status'] as String?) ?? (url != null ? 'onboarding' : (enabled ? 'active' : 'pending')),
      enabled: enabled,
      onboardingUrl: url,
      accountId: d['accountId'] as String?,
    );
  }

  String? _cachedBusinessId;

  Future<String> _businessId() async {
    if (_cachedBusinessId != null) return _cachedBusinessId!;
    final row = await _db.from('businesses').select('id').limit(1).single();
    return _cachedBusinessId = row['id'] as String;
  }

  Future<Invoice> _fetchInvoice(String id) async {
    final row = await _db.from('invoices').select(_invoiceSelect).eq('id', id).single();
    return _invoice(row);
  }

  // ─── Row mapping ──────────────────────────────────────────────────────────

  static double _num(dynamic v) =>
      v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);

  static DateTime? _ts(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

  static DateTime _date(dynamic v) => DateTime.parse(v.toString());

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _methodCode(String label) => switch (label.toLowerCase()) {
        'card' => 'card',
        'cash' => 'cash',
        'check' => 'check',
        'bank transfer' => 'bank_transfer',
        _ => 'other',
      };

  static Business _business(Map<String, dynamic> r) {
    final name = (r['name'] as String?) ?? '';
    return Business(
      name: name,
      initials: initialsOf(name.isEmpty ? 'New business' : name),
      email: (r['email'] as String?) ?? '',
      phone: (r['phone'] as String?) ?? '',
      address: (r['address'] as String?) ?? '',
      website: (r['website'] as String?) ?? '',
      taxId: (r['tax_id'] as String?) ?? '',
      taxRate: _num(r['tax_rate']),
      currency: (r['currency'] as String?)?.trim() ?? 'USD',
      dueInDays: (r['due_days'] as num?)?.toInt() ?? 14,
      plan: (r['plan'] as String?) ?? 'free',
      country: (r['country'] as String?)?.trim().toUpperCase() ?? 'US',
      paymentProvider: r['payment_provider'] as String?,
      paymentAccountId: r['payment_account_id'] as String?,
      paymentsEnabled: r['payments_enabled'] == true,
      platformFeeBps: (r['platform_fee_bps'] as num?)?.toInt() ?? 100,
      template: InvoiceTemplate.fromId(r['template'] as String?),
    );
  }

  static Client _client(Map<String, dynamic> r) {
    final id = r['id'] as String;
    final name = r['name'] as String;
    return Client(
      id: id,
      name: name,
      initials: initialsOf(name),
      email: (r['email'] as String?) ?? '',
      phone: (r['phone'] as String?) ?? '',
      address: (r['address'] as String?) ?? '',
      color: colorFor(id),
    );
  }

  static CatalogItem _item(Map<String, dynamic> r) {
    final kind = (r['kind'] as String) == 'product' ? 'Product' : 'Service';
    return CatalogItem(
      name: r['name'] as String,
      kind: kind,
      unit: (r['unit'] as String?) ?? 'flat',
      price: r['price'] == null ? null : _num(r['price']),
      priceLabel: r['price_label'] as String?,
      icon: iconForItem(r['name'] as String, kind),
    );
  }

  static Invoice _invoice(Map<String, dynamic> r) {
    final items = ((r['invoice_items'] as List?) ?? const []).cast<Map<String, dynamic>>().toList()
      ..sort((a, b) => ((a['position'] as num?) ?? 0).compareTo((b['position'] as num?) ?? 0));
    final paid = ((r['payments'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .fold<double>(0, (s, p) => s + _num(p['amount']));
    final statusName = r['status'] as String;
    return Invoice(
      id: r['id'] as String,
      number: r['number'] as String,
      client: _client(r['clients'] as Map<String, dynamic>),
      items: [
        for (final it in items) LineItem(name: it['name'] as String, qty: _num(it['qty']), rate: _num(it['rate'])),
      ],
      issued: _date(r['issued_on']),
      due: _date(r['due_on']),
      status: InvoiceStatus.values.firstWhere((s) => s.name == statusName, orElse: () => InvoiceStatus.draft),
      paidOn: r['paid_on'] == null ? null : _date(r['paid_on']),
      paid: paid,
      discount: _num(r['discount']),
      taxRate: _num(r['tax_rate']),
      isEstimate: r['kind'] == 'estimate',
      payToken: r['pay_token'] as String?,
    );
  }

  static Expense _expense(Map<String, dynamic> r) {
    final category = (r['category'] as String?) ?? 'Other';
    return Expense(
      name: r['name'] as String,
      category: category,
      date: _date(r['spent_on']),
      amount: _num(r['amount']),
      icon: iconForExpense(category),
      hasReceipt: r['receipt_path'] != null,
    );
  }
}
