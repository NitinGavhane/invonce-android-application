// Renders the in-app legal texts to standalone HTML pages for hosting
// (store listings need a public Privacy Policy URL).
//
//   dart run tool/export_legal.dart        → legal/*.html + legal/index.html
import 'dart:io';

import 'package:invonce/legal/legal_texts.dart';

String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

String _page(String title, String body, {bool index = false}) => '''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$title · $legalAppName</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Hanken+Grotesk:wght@400;500;600;700&family=JetBrains+Mono:wght@500&display=swap">
<style>
  :root{--wine:#4d1520;--parchment:#fbf9f6;--mauve:#825b63;--linen:#f2eee7;--lemon:#faffa7}
  body{margin:0;background:var(--parchment);color:var(--wine);font-family:'Hanken Grotesk',system-ui,sans-serif;line-height:1.55}
  main{max-width:720px;margin:0 auto;padding:48px 20px 80px}
  .eyebrow{font-family:'JetBrains Mono',monospace;font-size:11px;letter-spacing:.1em;text-transform:uppercase;color:var(--mauve)}
  h1{font-size:34px;letter-spacing:-.03em;margin:8px 0 6px}
  h2{font-size:19px;letter-spacing:-.02em;margin:28px 0 8px}
  p,li{font-size:16px;margin:0 0 10px}
  ul{padding-left:22px}
  .summary{color:var(--mauve);font-size:17px}
  nav a{display:block;padding:14px 16px;margin:8px 0;background:#fff;border:1px solid var(--linen);border-radius:14px;color:var(--wine);text-decoration:none;font-weight:600}
  nav a span{display:block;font-weight:400;color:var(--mauve);font-size:14px}
  footer{margin-top:40px;padding-top:16px;border-top:1px solid var(--linen);color:var(--mauve);font-size:13px}
  a{color:var(--wine)}
</style>
</head>
<body>
<main>
<p class="eyebrow">$legalAppName${index ? '' : ' · <a href="index.html" style="color:inherit">Legal</a>'}</p>
$body
<footer>Effective ${_esc(legalEffective)} · ${_esc(legalCompany)} · <a href="mailto:${_esc(legalEmail)}">${_esc(legalEmail)}</a></footer>
</main>
</body>
</html>
''';

String _doc(LegalDoc d) {
  final b = StringBuffer()
    ..writeln('<h1>${_esc(d.title)}</h1>')
    ..writeln('<p class="summary">${_esc(d.summary)}</p>');
  for (final s in d.sections) {
    b.writeln('<h2>${_esc(s.heading)}</h2>');
    final bullets = s.paragraphs.where((p) => p.startsWith('- ')).toList();
    final plain = s.paragraphs.where((p) => !p.startsWith('- ')).toList();
    for (final p in plain) {
      b.writeln('<p>${_esc(p).replaceAll('\n', '<br>')}</p>');
    }
    if (bullets.isNotEmpty) {
      b.writeln('<ul>');
      for (final p in bullets) {
        b.writeln('<li>${_esc(p.substring(2))}</li>');
      }
      b.writeln('</ul>');
    }
  }
  return b.toString();
}

void main() {
  final dir = Directory('legal')..createSync(recursive: true);
  for (final d in legalDocs) {
    File('${dir.path}/${d.id}.html').writeAsStringSync(_page(d.title, _doc(d)));
  }
  final nav = StringBuffer()
    ..writeln('<h1>Legal &amp; privacy</h1>')
    ..writeln('<p class="summary">Policies for the $legalAppName app and website.</p>')
    ..writeln('<nav>');
  for (final d in legalDocs) {
    nav.writeln('<a href="${d.id}.html">${_esc(d.title)}<span>${_esc(d.summary)}</span></a>');
  }
  nav.writeln('</nav>');
  File('${dir.path}/index.html').writeAsStringSync(_page('Legal', nav.toString(), index: true));
  stdout.writeln('Wrote ${legalDocs.length + 1} pages to ${dir.path}/');
}
