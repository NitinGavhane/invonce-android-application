import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:invonce/data/app_store.dart';
import 'package:invonce/data/demo_repository.dart';
import 'package:invonce/main.dart';
import 'package:invonce/screens/splash.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('launch flash plays over the first screen, then removes itself', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var firstFrame = 0;
    final store = AppStore(DemoRepository(), demo: true);
    await store.load();

    await tester.pumpWidget(InvonceApp(store: store, onFirstFrame: () => firstFrame++));
    await tester.pump(); // first frame → native splash would be dropped here
    expect(firstFrame, 1);

    await tester.pump(const Duration(milliseconds: 900)); // mid-flash: wordmark is on screen
    expect(find.text('Invonce'), findsOneWidget);
    expect(find.text('INVOICES THAT GET YOU PAID'), findsOneWidget);
    expect(find.text('Invoices that get you paid.'), findsOneWidget); // welcome screen already built underneath

    await tester.pumpAndSettle();
    expect(find.text('INVOICES THAT GET YOU PAID'), findsNothing); // overlay gone
    expect(find.byType(LaunchFlash), findsOneWidget); // wrapper stays, now just the child
    expect(find.text('Skip — explore the demo'), findsOneWidget);
  });
}
