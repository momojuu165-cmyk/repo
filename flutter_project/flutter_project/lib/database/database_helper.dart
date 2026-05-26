import 'package:supabase_flutter/supabase_flutter.dart';

/// Central Supabase client accessor.
/// Replaces the old SQLite DatabaseHelper singleton.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  DatabaseHelper._internal();

  SupabaseClient get client => Supabase.instance.client;

  /// Legacy compatibility shim — no longer needed but kept so any code
  /// that calls `DatabaseHelper.instance.database` compiles cleanly.
  SupabaseClient get database => client;
}
