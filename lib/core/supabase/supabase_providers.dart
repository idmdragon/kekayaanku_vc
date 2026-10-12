import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Whether this build has Supabase credentials. Overridden in tests.
final supabaseConfiguredProvider = Provider<bool>((ref) => Env.hasSupabase);

/// Only read when [supabaseConfiguredProvider] is true; `main` initialises it.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);
