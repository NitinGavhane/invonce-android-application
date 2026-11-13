import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'models.dart';

/// Demo seed used when no Supabase project is configured.
/// Fixed "today" so the demo reads the same every day.
final demoToday = DateTime(2026, 10, 3);

const demoBusiness = Business(
  name: 'Northwind Studio',
  initials: 'NS',
  email: 'hello@northwind.co',
  phone: '(503) 555-0199',
  address: '1180 NW Glisan St, Suite 300\nPortland, OR 97209',
  website: 'northwind.co',
);

const _atlas = Client(id: 'af', name: 'Atlas Fitness', initials: 'AF', email: 'billing@atlasfit.com', phone: '(503) 555-0120', address: '2200 NE Alberta St, Portland, OR 97211', color: Palette.rust);
const _cedar = Client(id: 'cp', name: 'Cedar & Pine Co', initials: 'CP', email: 'accounts@cedarpine.co', phone: '(503) 555-0109', address: '77 SE Grand Ave, Portland, OR 97214', color: Palette.midnight);
const _harbor = Client(id: 'hc', name: 'Harbor & Co', initials: 'HC', email: 'accounts@harbor.co', phone: '(503) 555-0142', address: '412 Market St, Portland, OR 97204', color: Palette.wine);
const _juniper = Client(id: 'jb', name: 'Juniper Bakery', initials: 'JB', email: 'orders@juniperbakery.com', phone: '(503) 555-0177', address: '88 SE Division St, Portland, OR 97202', color: Palette.midnight);
const _meadow = Client(id: 'mi', name: 'Meadow Interiors', initials: 'MI', email: 'hello@meadowinteriors.co', phone: '(503) 555-0163', address: '501 N Mississippi Ave, Portland, OR 97227', color: Palette.midnight);
const _vela = Client(id: 'vm', name: 'Vela Marketing', initials: 'VM', email: 'ap@velamarketing.com', phone: '(503) 555-0188', address: '1020 SW Taylor St, Portland, OR 97205', color: Palette.rust);

const demoClients = <Client>[_atlas, _cedar, _harbor, _juniper, _meadow, _vela];

Invoice _inv(String n, Client c, List<LineItem> items, DateTime issued, DateTime due, InvoiceStatus status,
        {DateTime? paidOn, bool viewed = false}) =>
    Invoice(
      id: 'd$n',
      number: 'INV-$n',
      client: c,
      items: items,
      issued: issued,
      due: due,
      status: status,
      paidOn: paidOn,
      paid: status == InvoiceStatus.paid ? items.fold(0.0, (s, i) => s + i.amount) : 0,
      viewed: viewed,
    );

/// Newest first. Paid history runs May → Oct so Reports has a curve.
final demoInvoices = <Invoice>[
  _inv('0013', _vela, const [LineItem(name: 'Website design', rate: 2400), LineItem(name: 'Hosting — annual', rate: 680)], DateTime(2026, 10, 3), DateTime(2026, 10, 14), InvoiceStatus.unpaid),
  _inv('0012', _harbor, const [LineItem(name: 'Brand identity system', rate: 900), LineItem(name: 'Landing page design', rate: 340)], DateTime(2026, 9, 26), DateTime(2026, 10, 10), InvoiceStatus.unpaid, viewed: true),
  _inv('0011', _cedar, const [LineItem(name: 'Packaging system', rate: 4300)], DateTime(2026, 9, 20), DateTime(2026, 10, 4), InvoiceStatus.paid, paidOn: DateTime(2026, 10, 2)),
  _inv('0010', _juniper, const [LineItem(name: 'Menu & packaging design', rate: 740)], DateTime(2026, 9, 14), DateTime(2026, 9, 28), InvoiceStatus.overdue),
  _inv('0009', _atlas, const [LineItem(name: 'Brand photography', rate: 2100)], DateTime(2026, 9, 10), DateTime(2026, 9, 24), InvoiceStatus.paid, paidOn: DateTime(2026, 9, 24)),
  _inv('0008', _meadow, const [LineItem(name: 'Showroom signage', rate: 1460)], DateTime(2026, 8, 29), DateTime(2026, 9, 12), InvoiceStatus.paid, paidOn: DateTime(2026, 9, 12)),
  _inv('0007', _juniper, const [LineItem(name: 'Bakery rebrand', rate: 5540)], DateTime(2026, 8, 26), DateTime(2026, 9, 9), InvoiceStatus.paid, paidOn: DateTime(2026, 9, 9)),
  _inv('0006', _vela, const [LineItem(name: 'Campaign landing pages', rate: 5160)], DateTime(2026, 8, 2), DateTime(2026, 8, 16), InvoiceStatus.paid, paidOn: DateTime(2026, 8, 16)),
  _inv('0005', _harbor, const [LineItem(name: 'Website redesign', rate: 3140)], DateTime(2026, 7, 31), DateTime(2026, 8, 14), InvoiceStatus.paid, paidOn: DateTime(2026, 8, 14)),
  _inv('0004', _cedar, const [LineItem(name: 'Brand identity system', rate: 5400)], DateTime(2026, 7, 10), DateTime(2026, 7, 24), InvoiceStatus.paid, paidOn: DateTime(2026, 7, 24)),
  _inv('0003', _meadow, const [LineItem(name: 'Catalog design', rate: 3000)], DateTime(2026, 6, 20), DateTime(2026, 7, 4), InvoiceStatus.paid, paidOn: DateTime(2026, 6, 30)),
  _inv('0002', _atlas, const [LineItem(name: 'Website design', rate: 4100)], DateTime(2026, 6, 8), DateTime(2026, 6, 22), InvoiceStatus.paid, paidOn: DateTime(2026, 6, 22)),
  _inv('0001', _cedar, const [LineItem(name: 'Brand photography', rate: 5600), LineItem(name: 'Logo design', rate: 600)], DateTime(2026, 5, 12), DateTime(2026, 5, 26), InvoiceStatus.paid, paidOn: DateTime(2026, 5, 20)),
];

Invoice _est(String n, Client c, List<LineItem> items, DateTime issued, InvoiceStatus status) => Invoice(
      id: 'e$n',
      number: 'EST-$n',
      client: c,
      items: items,
      issued: issued,
      due: issued.add(const Duration(days: 30)),
      status: status,
      isEstimate: true,
    );

final demoEstimates = <Invoice>[
  _est('0012', _vela, const [LineItem(name: 'Website design', rate: 2400), LineItem(name: 'Hosting — annual', rate: 680)], DateTime(2026, 10, 2), InvoiceStatus.sent),
  _est('0011', _meadow, const [LineItem(name: 'Showroom refresh', rate: 5400)], DateTime(2026, 10, 1), InvoiceStatus.accepted),
  _est('0010', _harbor, const [LineItem(name: 'Brand identity system', rate: 900), LineItem(name: 'Landing page design', rate: 340)], DateTime(2026, 9, 30), InvoiceStatus.draft),
  _est('0009', _atlas, const [LineItem(name: 'Brand photography', rate: 2100)], DateTime(2026, 9, 26), InvoiceStatus.sent),
];

const demoCatalog = <CatalogItem>[
  CatalogItem(name: 'Website design', kind: 'Service', unit: 'flat', price: 2400, icon: Icons.web_outlined),
  CatalogItem(name: 'Brand identity system', kind: 'Service', unit: 'flat', price: 900, icon: Icons.palette_outlined),
  CatalogItem(name: 'Consulting', kind: 'Service', unit: 'per hour', price: 150, priceLabel: '/hr', icon: Icons.schedule_outlined),
  CatalogItem(name: 'Hosting — annual', kind: 'Product', unit: 'per year', price: 680, icon: Icons.inventory_2_outlined),
  CatalogItem(name: 'Logo design', kind: 'Service', unit: 'flat', price: 600, icon: Icons.draw_outlined),
  CatalogItem(name: 'Landing page design', kind: 'Service', unit: 'flat', price: 340, icon: Icons.web_outlined),
  CatalogItem(name: 'Rush fee', kind: 'Service', unit: '25% of total', priceLabel: '25%', icon: Icons.bolt_outlined),
];

final demoExpenses = <Expense>[
  Expense(name: 'Design software', category: 'Software', date: DateTime(2026, 10, 1), amount: 49, icon: Icons.web_outlined),
  Expense(name: 'Client lunch — Harbor & Co', category: 'Meals', date: DateTime(2026, 9, 30), amount: 86, icon: Icons.restaurant_outlined),
  Expense(name: 'Flight to Seattle', category: 'Travel', date: DateTime(2026, 9, 28), amount: 412, icon: Icons.flight_outlined),
  Expense(name: 'Printer paper & toner', category: 'Office', date: DateTime(2026, 9, 26), amount: 64, icon: Icons.description_outlined, hasReceipt: false),
  Expense(name: 'Co-working desk', category: 'Office', date: DateTime(2026, 9, 24), amount: 350, icon: Icons.business_outlined),
];

final demoActivity = <String, List<Activity>>{
  'hc': [
    Activity(icon: Icons.visibility_outlined, title: 'Viewed INV-0012', when: DateTime(2026, 10, 2, 9, 14)),
    Activity(icon: Icons.send_rounded, title: 'Sent INV-0012 by email', when: DateTime(2026, 9, 26, 16, 2)),
  ],
};
