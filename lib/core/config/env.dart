/// Build-time configuration from `--dart-define-from-file=dart_defines.json`.
/// The file is git-ignored; see dart_defines.example.json.
abstract final class Env {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Supabase "publishable" key (formerly the anon key). Public by design;
  /// data safety comes from RLS.
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
