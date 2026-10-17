import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/view/app.dart';

class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'http://127.0.0.1:54321');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Env.supabaseAnonKey.isEmpty) {
    throw Exception('Falta SUPABASE_ANON_KEY. Corre con --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...');
  }

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );
  runApp(const App());
}
