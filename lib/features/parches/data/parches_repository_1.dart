import 'package:supabase_flutter/supabase_flutter.dart';
import '../../gastos/logic/balance_calculator.dart';

class ParchesRepository {
  SupabaseClient get client => Supabase.instance.client;

  Stream<List<Map<String, dynamic>>> watchParches() {
    return client.from('parches').stream(primaryKey: ['id']).order('created_at', ascending: false);
  }

  Future<String> crearParche(String nombre) async {
    final res = await client.from('parches').insert({'nombre': nombre, 'tipo': 'corto'}).select('id').single();
    return res['id'] as String;
  }

  Future<void> addMiembro(String parcheId, String nombre) async {
    await client.from('miembros').insert({'parche_id': parcheId, 'nombre': nombre.trim()});
  }

  Stream<List<Map<String, dynamic>>> watchMiembros(String parcheId) {
    return client.from('miembros').stream(primaryKey: ['id']).eq('parche_id', parcheId).order('created_at');
  }

  Stream<List<Map<String, dynamic>>> watchGastos(String parcheId) {
    return client.from('gastos').stream(primaryKey: ['id']).eq('parche_id', parcheId).order('created_at', ascending: false);
  }

  Future<void> addGasto({
    required String parcheId,
    required String descripcion,
    required num montoOriginal,
    required String moneda,
    required String quienPago,
    String categoria = 'general',
  }) async {
    final montoCop = BalanceCalculator.toCop(montoOriginal, moneda);
    await client.from('gastos').insert({
      'parche_id': parcheId,
      'descripcion': descripcion,
      'monto_original': montoOriginal,
      'moneda': moneda,
      'monto_cop': montoCop,
      'quien_pago': quienPago,
      'categoria': categoria,
    });
  }

  Future<Map<String, int>> getTotales(String parcheId) async {
    final gastos = await client.from('gastos').select('monto_cop').eq('parche_id', parcheId);
    final miembros = await client.from('miembros').select('id').eq('parche_id', parcheId);
    final total = (gastos as List).fold<int>(0, (s, g) => s + (g['monto_cop'] as int));
    return {'total_cop': total, 'total_miembros': (miembros as List).length};
  }
}
