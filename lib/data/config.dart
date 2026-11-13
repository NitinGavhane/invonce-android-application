/// Build-time configuration. Pass with
/// `flutter run --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_KEY=…`
/// (`SUPABASE_ANON_KEY` is accepted too). Without both values the app runs in
/// demo mode on in-memory sample data.
abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _publishable = String.fromEnvironment('SUPABASE_KEY');
  static const _anon = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Supabase "publishable" key (or legacy anon key) — safe to ship in the app.
  static String get supabaseKey => _publishable.isNotEmpty ? _publishable : _anon;

  static bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  static const _payBase = String.fromEnvironment('PAY_BASE_URL');

  /// Where public pay links point. Defaults to this project's `invoice-page`
  /// Edge Function; set PAY_BASE_URL once a custom domain fronts it.
  static String get payBaseUrl =>
      _payBase.isNotEmpty ? _payBase : '$supabaseUrl/functions/v1/invoice-page';
}
