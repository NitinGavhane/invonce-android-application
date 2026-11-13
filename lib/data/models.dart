import 'package:flutter/material.dart';

enum InvoiceStatus { draft, sent, unpaid, overdue, paid, accepted, voided }

/// The look of every invoice, estimate and receipt the business sends. One
/// choice applies to the on-screen preview, the PDF and the public pay page.
/// `id` is what the database stores — keep it stable.
enum InvoiceTemplate {
  daylit('daylit', 'Daylit', 'Modern', 'The Invonce house look: wine tile, lemon total.'),
  ledger('ledger', 'Ledger', 'Classic', 'Mono type and ruled lines, like a bookkeeper\'s ledger.'),
  clean('clean', 'Clean', 'Minimal', 'Grey on white with plenty of air. Nothing extra.'),
  bold('bold', 'Bold', 'Modern', 'Midnight header band and a big wine total bar.'),
  classic('classic', 'Classic', 'Classic', 'Centred title between double rules, traditional columns.'),
  compact('compact', 'Compact', 'Minimal', 'Everything tight so long invoices stay on one page.');

  const InvoiceTemplate(this.id, this.label, this.category, this.blurb);

  final String id;
  final String label;
  final String category;
  final String blurb;

  static InvoiceTemplate fromId(String? id) =>
      values.firstWhere((t) => t.id == id, orElse: () => InvoiceTemplate.daylit);
}

class Business {
  const Business({
    required this.name,
    required this.initials,
    required this.email,
    required this.phone,
    required this.address,
    required this.website,
    this.taxId = '',
    this.taxRate = 0.10,
    this.currency = 'USD',
    this.dueInDays = 14,
    this.plan = 'free',
    this.country = 'US',
    this.paymentProvider,
    this.paymentAccountId,
    this.paymentsEnabled = false,
    this.platformFeeBps = 100,
    this.template = InvoiceTemplate.daylit,
  });

  final String name;
  final String initials;
  final String email;
  final String phone;
  final String address;
  final String website;
  final String taxId;
  final double taxRate;
  final String currency;
  final int dueInDays;
  final String plan;

  /// ISO-3166 alpha-2. Decides the payment provider and the Pro price shown.
  final String country;

  /// 'stripe' | 'razorpay' once a payout account exists; null before.
  final String? paymentProvider;
  final String? paymentAccountId;

  /// True once the provider has verified the account and can accept charges.
  final bool paymentsEnabled;

  /// Invonce's cut of each online payment on the Free plan, in basis points (100 = 1 %). Pro pays 0.
  final int platformFeeBps;

  /// Document design used for every invoice, estimate and receipt.
  final InvoiceTemplate template;

  bool get isPro => plan == 'pro';

  /// Provider that will be used: the connected one, else the regional default.
  String get provider => paymentProvider ?? (country.toUpperCase() == 'IN' ? 'razorpay' : 'stripe');
  bool get usesRazorpay => provider == 'razorpay';
  bool get hasPaymentAccount => paymentAccountId != null && paymentAccountId!.isNotEmpty;

  /// What Invonce keeps from an online payment of [amount].
  double platformFeeOn(double amount) => isPro ? 0 : (amount * platformFeeBps / 10000 * 100).round() / 100;

  Business copyWith({
    String? name,
    String? initials,
    String? email,
    String? phone,
    String? address,
    String? website,
    String? taxId,
    double? taxRate,
    String? currency,
    int? dueInDays,
    String? plan,
    String? country,
    String? paymentProvider,
    String? paymentAccountId,
    bool? paymentsEnabled,
    int? platformFeeBps,
    InvoiceTemplate? template,
  }) {
    return Business(
      name: name ?? this.name,
      initials: initials ?? this.initials,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      website: website ?? this.website,
      taxId: taxId ?? this.taxId,
      taxRate: taxRate ?? this.taxRate,
      currency: currency ?? this.currency,
      dueInDays: dueInDays ?? this.dueInDays,
      plan: plan ?? this.plan,
      country: country ?? this.country,
      paymentProvider: paymentProvider ?? this.paymentProvider,
      paymentAccountId: paymentAccountId ?? this.paymentAccountId,
      paymentsEnabled: paymentsEnabled ?? this.paymentsEnabled,
      platformFeeBps: platformFeeBps ?? this.platformFeeBps,
      template: template ?? this.template,
    );
  }
}

/// Result of connecting / checking the business's payout account.
class PaymentsStatus {
  const PaymentsStatus({
    required this.provider,
    required this.status,
    required this.enabled,
    this.onboardingUrl,
    this.accountId,
  });

  final String provider;

  /// not_connected · onboarding · under_review · needs_clarification · active
  final String status;
  final bool enabled;

  /// Stripe only: hosted onboarding page to open in the browser.
  final String? onboardingUrl;
  final String? accountId;
}

/// KYC + settlement details Razorpay Route needs to create a linked account.
/// Sent straight to the connect function; never stored in Invonce's database.
class RazorpayOnboarding {
  const RazorpayOnboarding({
    required this.legalName,
    required this.displayName,
    required this.email,
    required this.phone,
    required this.businessType,
    required this.pan,
    required this.street,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.accountNumber,
    required this.ifsc,
    required this.beneficiaryName,
  });

  final String legalName;
  final String displayName;
  final String email;
  final String phone;
  final String businessType; // individual | proprietorship | partnership | private_limited | llp
  final String pan;
  final String street;
  final String city;
  final String state;
  final String postalCode;
  final String accountNumber;
  final String ifsc;
  final String beneficiaryName;

  Map<String, dynamic> toJson() => {
        'legalName': legalName,
        'displayName': displayName,
        'email': email,
        'phone': phone,
        'businessType': businessType,
        'pan': pan,
        'address': {'street1': street, 'city': city, 'state': state, 'postalCode': postalCode},
        'bank': {'accountNumber': accountNumber, 'ifsc': ifsc, 'beneficiaryName': beneficiaryName},
      };
}

/// What the business has collected through pay links.
class OnlineSummary {
  const OnlineSummary({required this.payments, required this.collected, required this.platformFees, this.lastPaidAt});

  final int payments;
  final double collected;
  final double platformFees;
  final DateTime? lastPaidAt;

  static const empty = OnlineSummary(payments: 0, collected: 0, platformFees: 0);
}

class Client {
  const Client({
    required this.id,
    required this.name,
    required this.initials,
    required this.email,
    required this.phone,
    required this.address,
    required this.color,
  });

  final String id;
  final String name;
  final String initials;
  final String email;
  final String phone;
  final String address;
  final Color color;
}

class LineItem {
  const LineItem({required this.name, this.qty = 1, required this.rate});

  final String name;
  final double qty;
  final double rate;

  double get amount => qty * rate;
}

class CatalogItem {
  const CatalogItem({
    required this.name,
    required this.kind,
    required this.unit,
    this.price,
    this.priceLabel,
    required this.icon,
  });

  final String name;
  final String kind; // Service | Product
  final String unit;
  final double? price;
  final String? priceLabel;
  final IconData icon;

  bool get isService => kind == 'Service';
}

class Invoice {
  const Invoice({
    required this.id,
    required this.number,
    required this.client,
    required this.items,
    required this.issued,
    required this.due,
    required this.status,
    this.paidOn,
    this.paid = 0,
    this.discount = 0,
    this.taxRate = 0,
    this.isEstimate = false,
    this.viewed = false,
    this.payToken,
  });

  final String id;
  final String number;
  final Client client;
  final List<LineItem> items;
  final DateTime issued;
  final DateTime due;
  final InvoiceStatus status;
  final DateTime? paidOn;

  /// Sum of payments recorded so far (partial payments / deposits).
  final double paid;
  final double discount;
  final double taxRate;
  final bool isEstimate;
  final bool viewed;

  /// Secret slug of the public "view & pay" page.
  final String? payToken;

  double get subtotal => items.fold(0, (sum, i) => sum + i.amount);
  double get tax => (subtotal - discount) * taxRate;
  double get total => subtotal - discount + tax;
  double get balance => total - paid;
  bool get isOpen =>
      status == InvoiceStatus.unpaid || status == InvoiceStatus.overdue;
  bool get isPaid => status == InvoiceStatus.paid;

  Invoice copyWith({
    String? id,
    String? number,
    Client? client,
    List<LineItem>? items,
    DateTime? issued,
    DateTime? due,
    InvoiceStatus? status,
    DateTime? paidOn,
    double? paid,
    double? discount,
    double? taxRate,
    bool? isEstimate,
    bool? viewed,
    String? payToken,
  }) {
    return Invoice(
      id: id ?? this.id,
      number: number ?? this.number,
      client: client ?? this.client,
      items: items ?? this.items,
      issued: issued ?? this.issued,
      due: due ?? this.due,
      status: status ?? this.status,
      paidOn: paidOn ?? this.paidOn,
      paid: paid ?? this.paid,
      discount: discount ?? this.discount,
      taxRate: taxRate ?? this.taxRate,
      isEstimate: isEstimate ?? this.isEstimate,
      viewed: viewed ?? this.viewed,
      payToken: payToken ?? this.payToken,
    );
  }
}

class Expense {
  const Expense({
    required this.name,
    required this.category,
    required this.date,
    required this.amount,
    required this.icon,
    this.hasReceipt = true,
  });

  final String name;
  final String category;
  final DateTime date;
  final double amount;
  final IconData icon;
  final bool hasReceipt;
}

class Activity {
  const Activity({required this.icon, required this.title, required this.when});

  final IconData icon;
  final String title;
  final DateTime when;
}
