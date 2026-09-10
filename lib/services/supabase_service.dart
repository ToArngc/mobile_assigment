import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static late final SupabaseClient client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: 'https://pnibgdjxopmvesyklcjt.supabase.co',
      publishableKey: 'sb_publishable_-FfWQTblsFvucpl2uVdYgw_vf-W9y1e',
    );
    client = Supabase.instance.client;
  }
}
