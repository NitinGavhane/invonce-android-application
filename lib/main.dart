import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/app_store.dart';
import 'data/config.dart';
import 'data/demo_repository.dart';
import 'data/repository.dart';
import 'data/supabase_repository.dart';
import 'screens/onboarding.dart';
import 'screens/splash.dart';
import 'shell.dart';
import 'theme/theme.dart';
import 'theme/tokens.dart';
import 'theme/typography.dart';
import 'widgets/widgets.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Hold the native launch screen (wine + mark) until our first frame, so the
  // flash animation continues from it with no white blink in between.
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  final InvonceRepository repo;
  if (AppConfig.hasSupabase) {
    await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseKey);
    repo = SupabaseRepository();
  } else {
    repo = DemoRepository();
  }
  final store = AppStore(repo, demo: !AppConfig.hasSupabase);
  if (store.demo) await store.load();

  runApp(InvonceApp(store: store, onFirstFrame: FlutterNativeSplash.remove));
}

class InvonceApp extends StatelessWidget {
  const InvonceApp({super.key, required this.store, this.onFirstFrame});

  final AppStore store;

  /// Called once the first frame is drawn (drops the native splash on device).
  final VoidCallback? onFirstFrame;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      store: store,
      child: MaterialApp(
        title: 'Invonce',
        debugShowCheckedModeBanner: false,
        theme: buildDaylitTheme(Brightness.light),
        darkTheme: buildDaylitTheme(Brightness.dark),
        // Locked to the Daylit light look for now; dark tokens are ready in
        // `Daylit.dark` when a theme toggle lands in More.
        themeMode: ThemeMode.light,
        // On wide screens (web / desktop previews) show the app inside a
        // phone-sized frame so it looks the way it will on a device.
        builder: (context, child) => _PhoneFrame(child: child!),
        home: LaunchFlash(onFirstFrame: onFirstFrame, child: const _Root()),
      ),
    );
  }
}

/// Demo mode → onboarding straight into the app.
/// Supabase mode → onboarding/sign-in until there is a session, then load.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final store = AppScope.read(context);
    if (store.demo) return const OnboardingScreen();

    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, _) {
        if (auth.currentSession == null) {
          if (store.loaded) WidgetsBinding.instance.addPostFrameCallback((_) => store.reset());
          return const OnboardingScreen();
        }
        return const _SessionGate();
      },
    );
  }
}

class _SessionGate extends StatefulWidget {
  const _SessionGate();

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  @override
  void initState() {
    super.initState();
    final store = AppScope.read(context);
    if (!store.loaded && !store.loading) store.load();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.watch(context);
    if (store.loaded) return const AppShell();
    return Scaffold(
      backgroundColor: context.dl.bg,
      body: Center(
        child: store.error != null
            ? Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 36, color: context.dl.muted),
                    const SizedBox(height: 12),
                    Text("Couldn't load your data", style: Fonts.section(context.dl.ink)),
                    const SizedBox(height: 6),
                    Text('${store.error}', textAlign: TextAlign.center, style: Fonts.caption(context.dl.muted)),
                    const SizedBox(height: 18),
                    DaylitButton('Try again', onTap: store.load),
                    const SizedBox(height: 8),
                    DaylitButton('Sign out', variant: DaylitVariant.ghost,
                        onTap: () => Supabase.instance.client.auth.signOut()),
                  ],
                ),
              )
            : const ReceiptMark(size: 56, paper: Palette.wine, ink: Palette.lemon),
      ),
    );
  }
}

class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) return child;
        return ColoredBox(
          color: const Color(0xFF1B0A0F),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              // Scale the whole phone down when the window is shorter than it.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  width: 410,
                  height: 874,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF140609),
                    borderRadius: BorderRadius.circular(54),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 40,
                        offset: const Offset(0, 24),
                      ),
                    ],
                  ),
                  // The frame never changes; keep it off the per-frame repaint path.
                  child: RepaintBoundary(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(44),
                      child: MediaQuery(
                        data: MediaQuery.of(context).copyWith(size: const Size(390, 854)),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
