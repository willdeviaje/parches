import 'package:supabase_flutter/supabase_flutter.dart';

class ParchesRepository {
  final SupabaseClient _client;
  ParchesRepository(this._client);

  // ===== PARCHES =====
  Future<List<Map<String, dynamic>>> getParches() async {
    final res = await _client.from('parches').select().order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<Map<String, dynamic>> createParche(String nombre) async {
    final res = await _client.from('parches').insert({'nombre': nombre.trim()}).select().single();
    return res;
  }

  Future<void> deleteParche(String id) async {
    // Primero borra dependencias si no tienes cascade en DB
    await _client.from('gastos').delete().eq('parche_id', id);
    await _client.from('miembros').delete().eq('parche_id', id);
    await _client.from('parches').delete().eq('id', id);
  }

  // ===== MIEMBROS =====
  Future<List<Map<String, dynamic>>> getMiembros(String parcheId) async {
    final res = await _client.from('miembros').select().eq('parche_id', parcheId).order('created_at');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> addMiembro({required String parcheId, required String nombre}) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty) throw Exception('El nombre no puede estar vacío');

    // Validación anti-duplicado case-insensitive
    final existentes = await _client
        .from('miembros')
        .select('id,nombre')
        .eq('parche_id', parcheId)
        .ilike('nombre', limpio);

    if (existentes.isNotEmpty) {
      throw Exception('Ya existe un miembro con el nombre "$limpio"');
    }

    await _client.from('miembros').insert({
      'parche_id': parcheId,
      'nombre': limpio,
    });
  }

  Future<void> deleteMiembro(String id) async {
    await _client.from('miembros').delete().eq('id', id);
  }

  // ===== GASTOS =====
  Future<List<Map<String, dynamic>>> getGastos(String parcheId) async {
    final res = await _client.from('gastos').select().eq('parche_id', parcheId).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> addGasto({
    required String parcheId,
    required String descripcion,
    required double monto,
    required String moneda,
    required String pagadoPor,
    required String pagadoPorId,
  }) async {
    await _client.from('gastos').insert({
      'parche_id': parcheId,
      'descripcion': descripcion.trim(),
      'monto': monto,
      'moneda': moneda,
      'pagado_por': pagadoPor,
      'pagado_por_id': pagadoPorId,
    });
  }

  Future<void> deleteGasto(String id) async {
    await _client.from('gastos').delete().eq('id', id);
  }
}
