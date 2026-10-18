import 'package:supabase_flutter/supabase_flutter.dart';

class ParchesRepository {
  final SupabaseClient _client;
  ParchesRepository(this._client);

  Future<List<Map<String, dynamic>>> getParches() async {
    final res = await _client.from('parches').select().order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<Map<String, dynamic>> createParche(String nombre) async {
    final res = await _client.from('parches').insert({'nombre': nombre.trim()}).select().single();
    return res;
  }

  Future<void> deleteParche(String id) async {
    await _client.from('parches').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getMiembros(String parcheId) async {
    final res = await _client.from('miembros').select().eq('parche_id', parcheId).order('created_at');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> addMiembro({required String parcheId, required String nombre}) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty) throw Exception('El nombre no puede estar vacío');
    try {
      await _client.from('miembros').insert({'parche_id': parcheId, 'nombre': limpio});
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw Exception('Ya existe "$limpio"');
      rethrow;
    }
  }

  Future<void> deleteMiembro(String id) async {
    await _client.from('miembros').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getGastos(String parcheId) async {
    final res = await _client.from('gastos').select('*, pagador:miembros!gastos_pagado_por_id_fkey(nombre), participantes:gastos_participantes(miembro_id, monto_a_pagar_cop, miembro:miembros(nombre))').eq('parche_id', parcheId).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> addGasto({
    required String parcheId,
    required String descripcion,
    required double monto,
    required String moneda,
    required String pagadoPorId,
    required List<String> participantesIds,
    required double tasaCambio,
  }) async {
    final montoCop = (monto * tasaCambio).toInt();

    final gasto = await _client.from('gastos').insert({
      'parche_id': parcheId,
      'descripcion': descripcion,
      'monto_original': monto,
      'moneda': moneda,
      'monto_cop': montoCop,
      'tasa_cambio': tasaCambio,
      'fecha_tasa': DateTime.now().toIso8601String().substring(0, 10),
      'pagado_por_id': pagadoPorId,
      'quien_pago': '',
      'categoria': 'general',
    }).select().single();

    final porPersona = (montoCop / participantesIds.length).floor();
    final resto = montoCop - (porPersona * participantesIds.length);
    final rows = participantesIds.asMap().entries.map((entry) {
      final idx = entry.key;
      final miembroId = entry.value;
      return {
        'gasto_id': gasto['id'],
        'miembro_id': miembroId,
        'monto_a_pagar_cop': porPersona + (idx == 0 ? resto : 0),
      };
    }).toList();

    await _client.from('gastos_participantes').insert(rows);
  }

  Future<void> deleteGasto(String id) async {
    await _client.from('gastos').delete().eq('id', id);
  }

  Future<Map<String, dynamic>> calcularBalanceDetallado(String parcheId) async {
    final miembros = await getMiembros(parcheId);
    final gastos = await _client.from('gastos').select().eq('parche_id', parcheId);
    final participantes = await _client.from('gastos_participantes').select('*, gasto:gastos!inner(parche_id)').eq('gasto.parche_id', parcheId);

    final pagado = <String, int>{};
    final debe = <String, int>{};
    final idANombre = {for (var m in miembros) m['id'] as String: m['nombre'] as String};

    for (var m in miembros) {
      pagado[m['id'] as String] = 0;
      debe[m['id'] as String] = 0;
    }

    for (var g in gastos) {
      final pagadorId = g['pagado_por_id'] as String?;
      if (pagadorId != null && pagado.containsKey(pagadorId)) {
        pagado[pagadorId] = pagado[pagadorId]! + (g['monto_cop'] as int);
      }
    }

    for (var p in participantes) {
      final miembroId = p['miembro_id'] as String;
      if (debe.containsKey(miembroId)) {
        debe[miembroId] = debe[miembroId]! + (p['monto_a_pagar_cop'] as int);
      }
    }

    final balancePorId = <String, int>{};
    for (var id in pagado.keys) balancePorId[id] = pagado[id]! - debe[id]!;

    final balancePorNombre = <String, int>{};
    for (var entry in balancePorId.entries) {
      balancePorNombre[idANombre[entry.key] ?? entry.key] = entry.value;
    }

    final deudores = balancePorId.entries.where((e) => e.value < 0).toList()..sort((a, b) => a.value.compareTo(b.value));
    final acreedores = balancePorId.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));

    final transferencias = <Map<String, dynamic>>[];
    int i = 0, j = 0;
    final deudoresCopy = deudores.map((e) => MapEntry(e.key, e.value)).toList();
    final acreedoresCopy = acreedores.map((e) => MapEntry(e.key, e.value)).toList();

    while (i < deudoresCopy.length && j < acreedoresCopy.length) {
      final deudor = deudoresCopy[i];
      final acreedor = acreedoresCopy[j];
      final monto = (-deudor.value).clamp(0, acreedor.value);
      if (monto > 0) {
        transferencias.add({'de': idANombre[deudor.key], 'a': idANombre[acreedor.key], 'monto': monto});
        deudoresCopy[i] = MapEntry(deudor.key, deudor.value + monto);
        acreedoresCopy[j] = MapEntry(acreedor.key, acreedor.value - monto);
      }
      if (deudoresCopy[i].value == 0) i++;
      if (acreedoresCopy[j].value == 0) j++;
    }

    return {'balance': balancePorNombre, 'transferencias': transferencias};
  }
}
