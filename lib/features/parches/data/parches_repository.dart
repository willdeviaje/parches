import 'package:supabase_flutter/supabase_flutter.dart';
import '../../gastos/logic/balance_calculator.dart';

class ParchesRepository {
  final SupabaseClient _client;
  ParchesRepository(this._client);

  SupabaseClient get client => _client;

  // --- PARCHES ---
  Future<List<Map<String, dynamic>>> getParches() async {
    final data = await _client.from('parches').select().order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Stream<List<Map<String, dynamic>>> watchParches() {
    return _client.from('parches').stream(primaryKey: ['id']).order('created_at', ascending: false);
  }

  Future<String> crearParche(String nombre) async {
    try {
      // Fix: tabla parches en Supabase MVP1 solo tiene nombre, no tipo
      final res = await _client.from('parches').insert({'nombre': nombre}).select('id').single();
      return res['id'] as String;
    } catch (e) {
      // Fallback por si la tabla sí tiene 'tipo' en otra rama
      if (e.toString().contains('tipo')) {
        final res = await _client.from('parches').insert({'nombre': nombre}).select('id').single();
        return res['id'] as String;
      }
      rethrow;
    }
  }

  Future<void> createParche(String nombre) async {
    await crearParche(nombre);
  }

  // --- MIEMBROS ---
  Future<List<Map<String, dynamic>>> getMiembros(String parcheId) async {
    final res = await _client.from('miembros').select().eq('parche_id', parcheId).order('created_at');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> addMiembro({required String parcheId, required String nombre}) async {
    await _client.from('miembros').insert({'parche_id': parcheId, 'nombre': nombre.trim()});
  }

  // compatibilidad con llamada posicional vieja: addMiembroOld(String, String)
  Future<void> addMiembroPosicional(String parcheId, String nombre) async {
    await addMiembro(parcheId: parcheId, nombre: nombre);
  }

  Stream<List<Map<String, dynamic>>> watchMiembros(String parcheId) {
    return _client.from('miembros').stream(primaryKey: ['id']).eq('parche_id', parcheId).order('created_at');
  }

  // --- GASTOS ---
  Stream<List<Map<String, dynamic>>> watchGastos(String parcheId) {
    return _client.from('gastos').stream(primaryKey: ['id']).eq('parche_id', parcheId).order('created_at', ascending: false);
  }

  Future<List<Map<String, dynamic>>> getGastosFuture(String parcheId) async {
    final data = await _client.from('gastos').select().eq('parche_id', parcheId).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> addGasto({
    required String parcheId,
    required String descripcion,
    required num montoOriginal,
    required String moneda,
    required String quienPago,
    String categoria = 'general',
    String divisionTipo = 'igual',
    List<Map<String, dynamic>>? divisionData,
  }) async {
    final montoCop = BalanceCalculator.toCop(montoOriginal, moneda);
    final payload = {
      'parche_id': parcheId,
      'descripcion': descripcion,
      'monto_original': montoOriginal,
      'moneda': moneda,
      'monto_cop': montoCop,
      'quien_pago': quienPago,
      'categoria': categoria,
      'division_tipo': divisionTipo,
      'division_data': divisionData,
    };
    try {
      await _client.from('gastos').insert(payload);
    } catch (e) {
      // Fallback si las columnas nuevas no existen aún (MVP1)
      if (e.toString().contains('division_tipo') || e.toString().contains('division_data')) {
        await _client.from('gastos').insert({
          'parche_id': parcheId,
          'descripcion': descripcion,
          'monto_original': montoOriginal,
          'moneda': moneda,
          'monto_cop': montoCop,
          'quien_pago': quienPago,
          'categoria': categoria,
        });
      } else {
        rethrow;
      }
    }
  }

  Future<Map<String, int>> getTotales(String parcheId) async {
    final gastos = await _client.from('gastos').select('monto_cop').eq('parche_id', parcheId);
    final miembros = await _client.from('miembros').select('id').eq('parche_id', parcheId);
    final total = (gastos as List).fold<int>(0, (s, g) => s + (g['monto_cop'] as int));
    return {'total_cop': total, 'total_miembros': (miembros as List).length};
  }
}
