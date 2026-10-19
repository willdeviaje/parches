import 'package:supabase_flutter/supabase_flutter.dart';

class ParchesRepository {
  final SupabaseClient _client;
  ParchesRepository(this._client);
  SupabaseClient get client => _client;

  Future<List<Map<String, dynamic>>> getParches() async {
    final res = await _client.from('parches').select().order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<Map<String, dynamic>> createParche(String nombre) async {
    final res = await _client.from('parches').insert({'nombre': nombre.trim()}).select().single();
    return res;
  }

  Future<String> crearParche(String nombre) async {
    final res = await createParche(nombre);
    return res['id'] as String;
  }

  Future<void> deleteParche(String id) async {
    try { await _client.from('gastos').delete().eq('parche_id', id); } catch (_) {}
    try { await _client.from('miembros').delete().eq('parche_id', id); } catch (_) {}
    await _client.from('parches').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getMiembros(String parcheId) async {
    final res = await _client.from('miembros').select().eq('parche_id', parcheId).order('created_at');
    return List<Map<String, dynamic>>.from(res);
  }

  Stream<List<Map<String, dynamic>>> watchMiembros(String parcheId) {
    return _client.from('miembros').stream(primaryKey: ['id']).eq('parche_id', parcheId).order('created_at');
  }

  Future<void> addMiembro({required String parcheId, required String nombre}) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty) return;
    await _client.from('miembros').insert({'parche_id': parcheId, 'nombre': limpio});
  }

  Future<void> deleteMiembro(String id) async {
    await _client.from('miembros').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getGastos(String parcheId) async {
    final res = await _client.from('gastos').select().eq('parche_id', parcheId).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  Stream<List<Map<String, dynamic>>> watchGastos(String parcheId) {
    return _client.from('gastos').stream(primaryKey: ['id']).eq('parche_id', parcheId).order('created_at', ascending: false);
  }

  // COMPATIBLE CON TODAS LAS VERSIONES DE AddGastoSheet
  Future<void> addGasto({
    required String parcheId,
    required String descripcion,
    double? monto,
    num? montoOriginal,
    String? moneda,
    String? pagadoPor,
    String? quienPago,
    String? quienPagoId,
    String? pagadoPorId,
    String? categoria,
    String? divisionTipo,
    dynamic divisionData,
    List<String>? participantesIds,
  }) async {
    final montoFinal = (montoOriginal ?? monto ?? 0).toDouble();
    final pagadorFinal = (quienPago ?? pagadoPor ?? '').trim();
    
    await _client.from('gastos').insert({
      'parche_id': parcheId,
      'descripcion': descripcion.trim(),
      'monto_original': montoFinal,
      'moneda': moneda ?? 'COP',
      'monto_cop': montoFinal.toInt(),
      'quien_pago': pagadorFinal,
      'categoria': categoria ?? 'general',
    });
  }

  Future<void> deleteGasto(String id) async {
    await _client.from('gastos').delete().eq('id', id);
  }

  Future<Map<String, dynamic>> calcularBalanceDetallado(String parcheId) async {
    final miembros = await getMiembros(parcheId);
    final gastos = await getGastos(parcheId);
    final total = gastos.fold<int>(0, (s, g) => s + ((g['monto_cop'] as int?) ?? (g['monto_original'] as num?)?.toInt() ?? 0));
    return {'miembros': miembros, 'gastos': gastos, 'total': total};
  }
}