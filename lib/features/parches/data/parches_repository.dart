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
    try { await _client.from('gastos').delete().eq('parche_id', id); } catch (_) {}
    try { await _client.from('miembros').delete().eq('parche_id', id); } catch (_) {}
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
    final existentes = await _client.from('miembros').select('id,nombre').eq('parche_id', parcheId).ilike('nombre', limpio);
    if (existentes.isNotEmpty) throw Exception('Ya existe un miembro con el nombre "$limpio"');
    await _client.from('miembros').insert({'parche_id': parcheId, 'nombre': limpio});
  }

  Future<void> deleteMiembro(String id) async {
    await _client.from('miembros').delete().eq('id', id);
  }

  // ===== GASTOS - CORREGIDO CON TUS COLUMNAS REALES =====
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
    List<String>? participantesIds,
  }) async {
    // Mapeo a tus columnas reales
    final payload = {
      'parche_id': parcheId,
      'descripcion': descripcion,
      'monto_original': monto,
      'moneda': moneda,
      'monto_cop': monto.toInt(), // por ahora COP = original, luego metemos conversión
      'quien_pago': pagadoPor,
      'categoria': 'general',
    };

    await _client.from('gastos').insert(payload);
  }

  Future<void> deleteGasto(String id) async {
    await _client.from('gastos').delete().eq('id', id);
  }

  // ===== BALANCE - usando tus columnas reales =====
  Map<String, double> calcularBalance(List<Map<String, dynamic>> miembros, List<Map<String, dynamic>> gastos) {
    final pagado = <String, double>{};
    final debe = <String, double>{};
    for (final m in miembros) {
      final nombre = m['nombre'] as String;
      pagado[nombre] = 0;
      debe[nombre] = 0;
    }

    for (final g in gastos) {
      // tu columna real es monto_original o monto_cop
      final monto = (g['monto_original'] as num? ?? g['monto_cop'] as num? ?? 0).toDouble();
      final pagador = g['quien_pago'] as String? ?? '';
      if (pagador.isEmpty) continue;

      // Por ahora divide entre todos los miembros actuales
      final participantes = miembros.map((m) => m['nombre'] as String).toList();
      if (participantes.isEmpty) continue;
      final porPersona = monto / participantes.length;

      pagado[pagador] = (pagado[pagador] ?? 0) + monto;
      for (final p in participantes) {
        if (debe.containsKey(p)) {
          debe[p] = debe[p]! + porPersona;
        }
      }
    }

    final balance = <String, double>{};
    for (final nombre in pagado.keys) {
      balance[nombre] = pagado[nombre]! - (debe[nombre] ?? 0);
    }
    return balance;
  }
}
