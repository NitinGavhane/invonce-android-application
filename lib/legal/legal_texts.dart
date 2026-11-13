// Pure Dart (no Flutter imports) so `tool/export_legal.dart` can render the
// same content to HTML for hosting. Replace every [BRACKETED] placeholder before
// publishing, and have a lawyer review for your jurisdiction.

const legalAppName = 'Invonce';
const legalCompany = '[COMPANY LEGAL NAME]';
const legalEmail = '[SUPPORT EMAIL]';
const legalAddress = '[COMPANY ADDRESS]';
const legalJurisdiction = '[COUNTRY / STATE]';
const legalEffective = '[EFFECTIVE DATE]';
const legalSite = '[WEBSITE URL]';

class LegalSection {
  const LegalSection(this.heading, this.paragraphs);

  final String heading;

  /// Lines starting with "- " render as bullet points.
  final List<String> paragraphs;
}

class LegalDoc {
  const LegalDoc({required this.id, required this.title, required this.summary, required this.sections});

  final String id;
  final String title;
  final String summary;
  final List<LegalSection> sections;
}

const legalDocs = <LegalDoc>[privacyPolicy, termsOfService, subscriptionPolicy, deletionPolicy, acceptableUse, cookieNotice, contactSupport];

LegalDoc legalDocById(String id) => legalDocs.firstWhere((d) => d.id == id);

// ─── Privacy Policy ─────────────────────────────────────────────────────────

const privacyPolicy = LegalDoc(
  id: 'privacy',
  title: 'Privacy Policy',
  summary: 'What we collect, why, who we share it with, and your rights.',
  sections: [
    LegalSection('Overview', [
      'This Privacy Policy explains how $legalCompany ("we", "us") collects, uses and protects information when you use the $legalAppName app and website (the "Service"). Effective $legalEffective.',
      'In short: we collect only what the Service needs to work, we never sell your data, and you can export or delete everything at any time.',
    ]),
    LegalSection('Information you give us', [
      '- Account: your email address and a password (stored only as a secure hash by our authentication provider).',
      '- Business profile: business name, contact details, address, tax ID, logo and signature.',
      '- Client records: names, email addresses, phone numbers and addresses of the people and companies you invoice.',
      '- Documents: invoices, estimates, receipts, line items, payments, expenses and the notes you attach to them.',
      '- Files you upload: logos, signatures and receipt photos.',
      'You are responsible for having a lawful basis to enter your clients\' details into the Service (for example, because you have a business relationship with them).',
    ]),
    LegalSection('Information collected automatically', [
      '- Device and usage data: device type, operating system, app version, language, and crash or error logs.',
      '- Activity: when an invoice is created, sent, viewed or paid, with timestamps.',
      'We do not use advertising identifiers and we do not run third-party advertising or tracking SDKs.',
    ]),
    LegalSection('How we use information', [
      '- To provide the Service: store and sync your data, generate PDFs, send documents on your instruction, and track payments.',
      '- To operate your account and subscription, including purchase verification with Apple or Google.',
      '- To keep the Service secure, prevent abuse and fix problems.',
      '- To communicate service messages (for example, a payment reminder you scheduled, or a security notice).',
      'We do not sell personal information and we do not use your data to train artificial-intelligence models.',
    ]),
    LegalSection('Who we share it with', [
      '- Supabase (hosting, authentication, database and file storage) — your data is stored in the region selected for our project.',
      '- Apple App Store and Google Play — to process Invonce Pro subscriptions. We never see your card number.',
      '- Payment processors (for example Stripe), only if you turn on online payments; they receive the invoice amount and the payer\'s payment details directly.',
      '- Email and messaging apps on your device, when you choose to send a document — the document leaves the app via the app you pick.',
      '- Authorities, when required by law, or to protect our rights and users.',
      'Each processor is bound by a data-processing agreement and may only use the data to provide its service to us.',
    ]),
    LegalSection('Data retention', [
      'Your data stays in your account for as long as you keep the account. Invoices and receipts are financial records, so we do not delete individual documents on your behalf; you can delete them in the app.',
      'When you delete your account, all data is removed from our production database immediately and from encrypted backups within 30 days.',
    ]),
    LegalSection('Security', [
      'All traffic is encrypted in transit (TLS). Data is encrypted at rest by our hosting provider. Every database table is protected by row-level security so an account can only ever read its own business\'s records. Access to production systems is limited and logged.',
    ]),
    LegalSection('Your rights', [
      '- Access and portability: export your data from More → Legal & privacy, or ask us at $legalEmail.',
      '- Correction: edit anything in the app at any time.',
      '- Deletion: More → Legal & privacy → Delete account, or email us.',
      '- Objection and restriction, where applicable under GDPR, UK GDPR, CCPA/CPRA or similar laws.',
      'If you are in the EU/EEA or UK you may also complain to your local supervisory authority. California residents: we do not "sell" or "share" personal information as defined by the CCPA.',
    ]),
    LegalSection('International transfers', [
      'Your data is processed where our hosting provider operates. Where data moves between regions, we rely on standard contractual clauses or an equivalent lawful mechanism.',
    ]),
    LegalSection('Children', [
      'The Service is for businesses and is not directed at anyone under 18. We do not knowingly collect data from children; if you believe a child has created an account, contact us and we will delete it.',
    ]),
    LegalSection('Changes', [
      'We will post any changes here and update the effective date. For material changes we will notify you in the app or by email before they take effect.',
    ]),
    LegalSection('Contact', [
      '$legalCompany\n$legalAddress\n$legalEmail',
    ]),
  ],
);

// ─── Terms of Service ───────────────────────────────────────────────────────

const termsOfService = LegalDoc(
  id: 'terms',
  title: 'Terms of Service',
  summary: 'The agreement between you and us for using Invonce.',
  sections: [
    LegalSection('Agreement', [
      'These Terms govern your use of $legalAppName, provided by $legalCompany. By creating an account or using the Service you agree to them. If you use the Service for a business, you confirm you can bind that business. Effective $legalEffective.',
    ]),
    LegalSection('The Service', [
      '$legalAppName lets you create invoices, estimates and receipts, manage clients and items, record payments and expenses, and send documents. We may add, change or remove features; we will not remove core invoicing features from a paid plan during a paid period without a refund.',
    ]),
    LegalSection('Your account', [
      '- You must be at least 18 and provide accurate information.',
      '- Keep your password confidential; you are responsible for activity on your account.',
      '- One account per person or business unless we agree otherwise.',
    ]),
    LegalSection('Your content', [
      'You own the invoices, client records, files and other content you put into the Service. You grant us a licence to store, process, back up and display it solely to provide the Service to you.',
      'You are responsible for the accuracy of your documents and for complying with the invoicing, tax and record-keeping rules that apply to your business. $legalAppName is a tool, not accounting, legal or tax advice.',
    ]),
    LegalSection('Acceptable use', [
      'You must not use the Service to issue fraudulent or misleading invoices, to send unsolicited messages, to infringe anyone\'s rights, or to break the law. See the Acceptable Use Policy for details. We may suspend accounts that breach it.',
    ]),
    LegalSection('Subscriptions', [
      'Some features require Invonce Pro, an auto-renewing subscription purchased through the Apple App Store or Google Play. Pricing, trials, renewal and cancellation are described in the Subscription & Refund Policy and at the point of purchase.',
    ]),
    LegalSection('Payments between you and your clients', [
      'Where online payments are enabled, they are processed by a third-party payment provider under its own terms. We are not a party to transactions between you and your clients and do not hold funds on your behalf.',
    ]),
    LegalSection('Availability and support', [
      'We aim for high availability but do not guarantee the Service will be uninterrupted or error-free. We may perform maintenance with reasonable notice. Support is available at $legalEmail.',
    ]),
    LegalSection('Intellectual property', [
      'The Service, its design, software and trade marks belong to $legalCompany or its licensors. You may not copy, modify, reverse-engineer or resell the Service except as permitted by law.',
    ]),
    LegalSection('Disclaimer and limitation of liability', [
      'The Service is provided "as is". To the fullest extent permitted by law we exclude all implied warranties, and our total liability for any claim arising from the Service is limited to the amount you paid us in the 12 months before the claim. We are not liable for indirect or consequential losses, including lost revenue or data, except where liability cannot be limited by law.',
    ]),
    LegalSection('Termination', [
      'You can delete your account at any time in the app. We may suspend or terminate accounts for breach of these Terms, with notice where practical. On termination your right to use the Service ends; the Privacy Policy explains what happens to your data.',
    ]),
    LegalSection('Changes to these Terms', [
      'We may update these Terms. We will notify you of material changes in the app or by email at least 14 days before they take effect. Continuing to use the Service after that means you accept the new Terms.',
    ]),
    LegalSection('Governing law', [
      'These Terms are governed by the laws of $legalJurisdiction, and disputes will be handled by the courts there, without affecting any mandatory consumer protections where you live.',
    ]),
    LegalSection('Contact', ['$legalCompany\n$legalAddress\n$legalEmail']),
  ],
);

// ─── Subscription & Refund Policy ───────────────────────────────────────────

const subscriptionPolicy = LegalDoc(
  id: 'subscription',
  title: 'Subscription & Refund Policy',
  summary: 'How Invonce Pro billing, trials, cancellation and refunds work.',
  sections: [
    LegalSection('Plans', [
      '- Free: core invoicing with a limited number of documents and the $legalAppName watermark.',
      '- Invonce Pro: unlimited invoices, estimates and clients; no watermark; read receipts; reminders; recurring invoices; expense tracking and exports; all templates; priority support.',
      'Current prices are shown in the app before you subscribe and may vary by country and currency.',
    ]),
    LegalSection('Free trial', [
      'New subscribers may be offered a 7-day free trial. You can cancel at any time during the trial and you will not be charged. If you do not cancel, the subscription starts automatically when the trial ends.',
    ]),
    LegalSection('Billing and renewal', [
      'Subscriptions are billed to your Apple App Store or Google Play account and renew automatically (monthly or yearly, as chosen) unless cancelled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours before the period ends.',
    ]),
    LegalSection('Cancellation', [
      '- iOS: Settings → your name → Subscriptions → Invonce → Cancel.',
      '- Android: Google Play → Profile → Payments & subscriptions → Subscriptions → Invonce → Cancel.',
      'Cancelling stops future renewals; you keep Pro until the end of the period you have paid for. Deleting the app does not cancel a subscription.',
    ]),
    LegalSection('Refunds', [
      'Purchases are made through Apple or Google, and refunds are handled under their policies. Request one at reportaproblem.apple.com or through Google Play\'s order history. We cannot issue refunds directly for store purchases, but contact us at $legalEmail and we will help.',
    ]),
    LegalSection('Price changes', [
      'If we change the price of a subscription, we will notify you in advance through the store. Where required, the new price will apply only after you have agreed to it.',
    ]),
  ],
);

// ─── Data & Account Deletion ────────────────────────────────────────────────

const deletionPolicy = LegalDoc(
  id: 'deletion',
  title: 'Data & Account Deletion',
  summary: 'How to delete your account and what happens to your data.',
  sections: [
    LegalSection('Delete your account in the app', [
      'More → Legal & privacy → Delete account. You will be asked to confirm. Deletion is immediate and cannot be undone.',
    ]),
    LegalSection('Delete your account by email', [
      'If you can no longer sign in, email $legalEmail from the address on the account with the subject "Delete my account". We will verify the request and complete it within 7 days.',
    ]),
    LegalSection('What is deleted', [
      '- Your login and profile.',
      '- Your business profile, logo and signature.',
      '- All clients, items, invoices, estimates, receipts, payments, expenses and activity history.',
      '- All files you uploaded.',
      'Deleted data is removed from our production systems immediately and from encrypted backups within 30 days.',
    ]),
    LegalSection('What may be kept', [
      '- Records we must keep by law (for example, our own tax records of your subscription purchase), for as long as the law requires.',
      '- Anonymised, aggregated statistics that cannot identify you.',
      'Your Apple or Google subscription is managed by the store; cancel it separately (see the Subscription & Refund Policy) so you are not charged again.',
    ]),
    LegalSection('Export before you go', [
      'Before deleting, you can save PDF copies of any document from the app and request a full data export at $legalEmail.',
    ]),
  ],
);

// ─── Acceptable Use Policy ──────────────────────────────────────────────────

const acceptableUse = LegalDoc(
  id: 'acceptable-use',
  title: 'Acceptable Use Policy',
  summary: 'What you may and may not do with the Service.',
  sections: [
    LegalSection('You agree not to', [
      '- Create invoices, estimates or receipts that are false, misleading, or for goods or services that were not provided.',
      '- Use the Service to send unsolicited commercial messages or to harass anyone.',
      '- Enter personal data about people you have no legitimate business relationship with.',
      '- Sell or invoice for illegal goods or services, or use the Service to launder money or evade tax.',
      '- Upload malware, attempt to access other accounts, probe or overload our systems, or bypass security or usage limits.',
      '- Reverse-engineer, scrape or resell the Service without our written permission.',
    ]),
    LegalSection('Enforcement', [
      'We may remove content, suspend or terminate accounts, and report unlawful activity to authorities. Where practical we will tell you why and give you a chance to respond.',
    ]),
    LegalSection('Reporting', [
      'To report abuse, email $legalEmail with the details.',
    ]),
  ],
);

// ─── Cookie & Local Storage Notice ──────────────────────────────────────────

const cookieNotice = LegalDoc(
  id: 'cookies',
  title: 'Cookie & Local Storage Notice',
  summary: 'What the web version of Invonce stores in your browser.',
  sections: [
    LegalSection('What we store', [
      '- Session token (essential): keeps you signed in. Stored in your browser\'s local storage by our authentication provider and removed when you sign out.',
      '- Preferences (essential): small settings such as the last tab or filter you used.',
      'We do not use advertising, analytics or cross-site tracking cookies.',
    ]),
    LegalSection('Fonts', [
      'The mobile apps bundle their fonts. The web version may load fonts from Google Fonts, which can receive your IP address as part of the request.',
    ]),
    LegalSection('Managing storage', [
      'Signing out clears the session. You can also clear site data in your browser settings; you will then need to sign in again.',
    ]),
  ],
);

// ─── Contact & Support ──────────────────────────────────────────────────────

const contactSupport = LegalDoc(
  id: 'contact',
  title: 'Contact & Support',
  summary: 'How to reach us.',
  sections: [
    LegalSection('Support', [
      'Email $legalEmail. We aim to reply within 2 business days (1 business day for Invonce Pro).',
    ]),
    LegalSection('Privacy requests', [
      'For access, export, correction or deletion requests, email $legalEmail with the subject "Privacy request".',
    ]),
    LegalSection('Company', ['$legalCompany\n$legalAddress\n$legalSite']),
  ],
);
