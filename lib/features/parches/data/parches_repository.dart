import 'package:supabase_flutter/supabase_flutter.dart';

class ParchesRepository {
  final SupabaseClient _client;
  ParchesRepository(this._client);

  // PARCHES
  Future<List<Map<String, dynamic>>> getParches() async {
    final res = await _client.from('parches').select().order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> createParche(String nombre) async {
    final userId = _client.auth.currentUser?.id;
    await _client.from('parches').insert({
      'nombre': nombre,
      'created_by': userId,
    });
  }

  Future<void> deleteParche(String id) async {
    await _client.from('parches').delete().eq('id', id);
  }

  // MIEMBROS
  Future<List<Map<String, dynamic>>> getMiembros(String parcheId) async {
    final res = await _client.from('miembros').select().eq('parche_id', parcheId).order('created_at');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> addMiembro({required String parcheId, required String nombre}) async {
    final existing = await _client.from('miembros').select().eq('parche_id', parcheId).ilike('nombre', nombre);
    if (existing.isNotEmpty) throw Exception('Ya existe ese miembro');
    await _client.from('miembros').insert({'parche_id': parcheId, 'nombre': nombre});
  }

  Future<void> deleteMiembro(String id) async {
    await _client.from('miembros').delete().eq('id', id);
  }

  // GASTOS
  Future<List<Map<String, dynamic>>> getGastos(String parcheId) async {
    final res = await _client
        .from('gastos')
        .select('*, pagador:miembros!gastos_pagado_por_id_fkey(nombre), participantes:gastos_participantes(miembro_id, miembro:miembros(nombre))')
        .eq('parche_id', parcheId)
        .order('created_at', ascending: false);
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
    final montoCop = (monto * tasaCambio).round();
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
    }).select('id').single();
    final gastoId = gasto['id'] as String;
    final rows = participantesIds.map((id) => {'gasto_id': gastoId, 'miembro_id': id}).toList();
    if (rows.isNotEmpty) await _client.from('gastos_participantes').insert(rows);
  }

  Future<void> updateGasto({
    required String gastoId,
    required String descripcion,
    required double monto,
    required String moneda,
    required String pagadoPorId,
    required List<String> participantesIds,
    required double tasaCambio,
  }) async {
    final montoCop = (monto * tasaCambio).round();
    await _client.from('gastos').update({
      'descripcion': descripcion,
      'monto_original': monto,
      'moneda': moneda,
      'monto_cop': montoCop,
      'tasa_cambio': tasaCambio,
      'pagado_por_id': pagadoPorId,
    }).eq('id', gastoId);
    await _client.from('gastos_participantes').delete().eq('gasto_id', gastoId);
    final rows = participantesIds.map((id) => {'gasto_id': gastoId, 'miembro_id': id}).toList();
    if (rows.isNotEmpty) await _client.from('gastos_participantes').insert(rows);
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
    for (var m in miembros) { pagado[m['id'] as String] = 0; debe[m['id'] as String] = 0; }
    for (var g in gastos) {
      final pid = g['pagado_por_id'] as String?;
      if (pid != null && pagado.containsKey(pid)) pagado[pid] = (pagado[pid] ?? 0) + (g['monto_cop'] as int? ?? 0);
    }
    final Map<String, List<String>> gastoToMiembros = {};
    for (var p in participantes) {
      gastoToMiembros.putIfAbsent(p['gasto_id'] as String, () => []).add(p['miembro_id'] as String);
    }
    for (var g in gastos) {
      final gid = g['id'] as String;
      final total = g['monto_cop'] as int? ?? 0;
      final mids = gastoToMiembros[gid] ?? [];
      if (mids.isEmpty) continue;
      final perCapita = (total / mids.length).round();
      for (var mid in mids) { if (debe.containsKey(mid)) debe[mid] = (debe[mid] ?? 0) + perCapita; }
    }
    final balance = <String, int>{};
    for (var id in idANombre.keys) { balance[idANombre[id]!] = (pagado[id] ?? 0) - (debe[id] ?? 0); }
    final deudores = balance.entries.where((e) => e.value < 0).map((e) => MapEntry(e.key, -e.value)).toList()..sort((a,b)=>b.value.compareTo(a.value));
    final acreedores = balance.entries.where((e) => e.value > 0).toList()..sort((a,b)=>b.value.compareTo(a.value));
    final transferencias = <Map<String, dynamic>>[];
    int i=0,j=0;
    while(i<deudores.length && j<acreedores.length){
      final monto = deudores[i].value < acreedores[j].value ? deudores[i].value : acreedores[j].value;
      if(monto>0) transferencias.add({'de':deudores[i].key,'a':acreedores[j].key,'monto':monto});
      deudores[i]=MapEntry(deudores[i].key,deudores[i].value-monto);
      acreedores[j]=MapEntry(acreedores[j].key,acreedores[j].value-monto);
      if(deudores[i].value==0) i++; if(acreedores[j].value==0) j++;
    }
    return {'balance':balance,'transferencias':transferencias};
  }
}