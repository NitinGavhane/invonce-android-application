import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'models.dart';

/// Everything the app needs on launch.
class Snapshot {
  const Snapshot({
    required this.business,
    required this.clients,
    required this.items,
    required this.documents,
    required this.expenses,
    required this.events,
  });

  final Business business;
  final List<Client> clients;
  final List<CatalogItem> items;

  /// Invoices and estimates together, newest first.
  final List<Invoice> documents;
  final List<Expense> expenses;

  /// Activity per client id.
  final Map<String, List<Activity>> events;
}

/// Data source contract. Implemented by [DemoRepository] (in-memory) and
/// [SupabaseRepository] (Postgres via Supabase).
abstract class InvonceRepository {
  Future<Snapshot> load();

  /// Persists a draft; the returned invoice carries the real id and number.
  Future<Invoice> createInvoice(Invoice draft);

  Future<Invoice> recordPayment(
    Invoice invoice, {
    required double amount,
    required String method,
    String? reference,
    String? note,
  });

  Future<Client> createClient({
    required String name,
    required String email,
    required String phone,
    String address = '',
  });

  Future<Client> updateClient(Client client);

  Future<CatalogItem> createItem({
    required String name,
    required String kind,
    required String unit,
    double? price,
    String? priceLabel,
  });

  Future<Expense> createExpense({
    required String name,
    required String category,
    required double amount,
    required DateTime date,
  });

  Future<Invoice> updateStatus(Invoice invoice, InvoiceStatus status);

  Future<Business> updateBusiness(Business business);

  Future<void> logEvent(Invoice invoice, String type);

  /// Permanently removes the account and every record it owns.
  Future<void> deleteAccount();

  // ─── Online payments ──────────────────────────────────────────────────────

  /// Starts payout onboarding. Stripe returns a hosted URL to open; Razorpay
  /// needs [razorpay] KYC details and returns the review status.
  Future<PaymentsStatus> connectPayments({RazorpayOnboarding? razorpay});

  /// Asks the provider whether the account can take payments yet.
  Future<PaymentsStatus> paymentsStatus();

  /// Totals of what has been collected through pay links.
  Future<OnlineSummary> onlineSummary();
}

String initialsOf(String name) {
  final parts = name
      .split(RegExp(r'[\s&]+'))
      .where((p) => p.isNotEmpty && RegExp(r'[A-Za-z0-9]').hasMatch(p[0]))
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

/// Stable avatar colour for a client, from the three brand darks.
Color colorFor(String key) {
  const palette = [Palette.wine, Palette.midnight, Palette.rust];
  return palette[key.hashCode.abs() % palette.length];
}

IconData iconForItem(String name, String kind) {
  final n = name.toLowerCase();
  if (n.contains('web') || n.contains('page') || n.contains('site')) return Icons.web_outlined;
  if (n.contains('brand') || n.contains('identity')) return Icons.palette_outlined;
  if (n.contains('consult') || n.contains('hour')) return Icons.schedule_outlined;
  if (n.contains('logo') || n.contains('design')) return Icons.draw_outlined;
  if (n.contains('rush') || n.contains('fee')) return Icons.bolt_outlined;
  return kind.toLowerCase() == 'product' ? Icons.inventory_2_outlined : Icons.handyman_outlined;
}

IconData iconForExpense(String category) => switch (category.toLowerCase()) {
      'software' => Icons.web_outlined,
      'meals' => Icons.restaurant_outlined,
      'travel' => Icons.flight_outlined,
      'office' => Icons.business_outlined,
      _ => Icons.receipt_long_outlined,
    };

IconData iconForEvent(String type) => switch (type) {
      'viewed' => Icons.visibility_outlined,
      'sent' => Icons.send_rounded,
      'paid' => Icons.check_rounded,
      'reminded' => Icons.notifications_none_rounded,
      'accepted' => Icons.task_alt_rounded,
      _ => Icons.description_outlined,
    };
