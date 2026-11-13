import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:invonce/data/app_store.dart';
import 'package:invonce/data/demo_repository.dart';
import 'package:invonce/data/format.dart';
import 'package:invonce/data/models.dart';
import 'package:invonce/data/pricing.dart';
import 'package:invonce/main.dart';

/// Online payments: regional pricing, provider choice, fees, pay links, and
/// the connect flow driven through the real screens (demo repository).
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const blank = Business(name: '', initials: '', email: '', phone: '', address: '', website: '');

  group('regional pricing', () {
    test('India gets INR, euro countries EUR, unknown falls back to USD', () {
      expect(proPriceFor('IN').monthlyLabel, '₹499');
      expect(proPriceFor('in').yearlyLabel, '₹2999');
      expect(proPriceFor('DE').currency, 'EUR');
      expect(proPriceFor('ZZ').currency, 'USD');
      expect(proPriceFor('US').monthlyLabel, '\$9.99');
      expect(proPriceFor('US').yearlySavingPct, 42);
    });

    test('payment provider follows the country', () {
      expect(providerFor('IN'), 'razorpay');
      expect(providerFor('US'), 'stripe');
      expect(providerFor('GB'), 'stripe');
      expect(blank.copyWith(country: 'IN').provider, 'razorpay');
      expect(blank.copyWith(country: 'IN', paymentProvider: 'stripe').provider, 'stripe');
    });

    test('money formats in the business currency', () {
      expect(money(1240, currency: 'INR'), '₹1,240.00');
      expect(money(1240, currency: 'JPY'), '¥1,240');
      expect(money(1240.5), '\$1,240.50');
      expect(money(-5, currency: 'GBP'), '−£5.00');
    });

    test('platform fee is 1% on Free and 0% on Pro', () {
      expect(blank.platformFeeOn(1000), 10);
      expect(blank.copyWith(plan: 'pro').platformFeeOn(1000), 0);
      expect(feePct(100), '1%');
      expect(feePct(150), '1.5%');
    });
  });

  group('store', () {
    test('pay link is empty for drafts and carries the token once saved', () async {
      final store = AppStore(DemoRepository(), demo: true);
      await store.load();
      final draft = store.newDraft(client: store.clients.first, items: const [LineItem(name: 'Logo', rate: 600)]);
      expect(store.payLinkFor(draft), '');
      final saved = await store.saveInvoice(draft);
      expect(saved.payToken, isNotNull);
      expect(store.payLinkFor(saved), 'https://invonce.app/pay/${saved.payToken}');
    });

    test('connect → check status activates payments and loads earnings', () async {
      final store = AppStore(DemoRepository(), demo: true);
      await store.load();
      expect(store.business.paymentsEnabled, isFalse);

      final started = await store.connectPayments();
      expect(started.provider, 'stripe');
      expect(started.onboardingUrl, isNotNull);
      expect(store.business.hasPaymentAccount, isTrue);
      expect(store.business.paymentsEnabled, isFalse);

      final checked = await store.refreshPaymentsStatus();
      expect(checked.enabled, isTrue);
      expect(store.business.paymentsEnabled, isTrue);

      final online = await store.refreshOnline();
      expect(online.payments, 3);
      expect(online.platformFees, closeTo(online.collected * 0.01, 0.01));
    });
  });

  // ─── Screen flows ─────────────────────────────────────────────────────────

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
  Future<void> tapTab(WidgetTester tester, String label) => tapFinder(tester, find.text(label).last);

  Future<void> skipToHome(WidgetTester tester) async {
    await tapText(tester, 'Skip — explore the demo');
    expect(find.text('Northwind Studio'), findsOneWidget);
  }

  testWidgets('payment methods: Connect Stripe → Check status → Active, fees explained', (tester) async {
    // url_launcher has no platform side in tests; answer its channel and record the URL.
    String? opened;
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'launch') opened = (call.arguments as Map)['url'] as String;
      return true;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

    final store = await launch(tester);
    await skipToHome(tester);
    await tapTab(tester, 'More');
    await tapText(tester, 'Payment methods');

    expect(find.text('NOT CONNECTED'), findsOneWidget); // status pill
    expect(find.text('Stripe · United States'), findsOneWidget);
    expect(find.text('1%'), findsOneWidget); // Invonce platform fee row
    expect(find.text('Keep 100% of every online payment with Pro'), findsOneWidget);

    await tapText(tester, 'Connect Stripe');
    expect(store.business.hasPaymentAccount, isTrue);
    expect(opened, 'https://connect.stripe.com/setup/e/demo'); // hosted onboarding opened in the browser
    expect(find.text('PENDING'), findsOneWidget);
    expect(find.text('Continue setup'), findsOneWidget);

    await tapText(tester, 'Check status');
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(store.business.paymentsEnabled, isTrue);
    expect(find.text('Refresh'), findsOneWidget);
    expect(find.text('COLLECTED ONLINE'), findsOneWidget);
  });

  testWidgets('business profile: pick India → Razorpay setup with KYC validation; paywall shows ₹', (tester) async {
    final store = await launch(tester);
    await skipToHome(tester);
    await tapTab(tester, 'More');
    await tapText(tester, 'Business profile & logo');

    await tapText(tester, 'United States');
    await tapText(tester, 'India');
    expect(find.text('India'), findsOneWidget);
    await tapText(tester, 'Save profile');
    expect(store.business.country, 'IN');
    expect(store.business.currency, 'INR');

    await tapText(tester, 'Payment methods');
    expect(find.text('Razorpay · India'), findsOneWidget);
    await tapText(tester, 'Set up Razorpay');
    expect(find.text('Submit to Razorpay'), findsOneWidget);
    await tapText(tester, 'Submit to Razorpay'); // prefilled name/email/phone; PAN is empty
    expect(find.text('PAN looks wrong (e.g. ABCDE1234F)'), findsOneWidget);
    expect(store.business.hasPaymentAccount, isFalse);
    Navigator.of(tester.element(find.text('Submit to Razorpay'))).pop();
    await tester.pumpAndSettle();

    await tapText(tester, 'Keep 100% of every online payment with Pro'); // Pro upsell → paywall
    expect(find.textContaining('₹499', findRichText: true), findsOneWidget); // price + "/mo" span
    expect(find.textContaining('₹2999', findRichText: true), findsOneWidget);
    expect(find.textContaining('Prices in INR for India'), findsOneWidget);
  });

  testWidgets('send sheet → Payment link copies the public pay URL', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await launch(tester);
    await skipToHome(tester);
    await tapTab(tester, 'Invoices');
    await tapFinder(tester, find.textContaining('INV-0012').first); // row subtitle "INV-0012 · Oct 3"
    await tapText(tester, 'Send invoice');
    await tapText(tester, 'Payment link');
    await tapText(tester, 'Copy payment link');

    expect(copied, startsWith('https://invonce.app/pay/'));
    expect(find.textContaining('Link copied'), findsOneWidget); // payments not connected yet → hint
  });
}
