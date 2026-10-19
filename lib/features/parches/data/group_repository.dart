import 'package:supabase_flutter/supabase_flutter.dart';

class GroupRepository {
  final SupabaseClient _client;
  GroupRepository(this._client);

  Future<List<Map<String, dynamic>>> getGroups() async {
    final res = await _client.from('parches').select().order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<Map<String, dynamic>> createGroup(String name) async {
    final res = await _client.from('parches').insert({'nombre': name.trim()}).select().single();
    return res;
  }

  Future<void> deleteGroup(String id) async {
    await _client.from('parches').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getMembers(String groupId) async {
    final res = await _client.from('miembros').select().eq('parche_id', groupId).order('created_at');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> addMember({required String groupId, required String name}) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw Exception('Name cannot be empty');
    try {
      await _client.from('miembros').insert({'parche_id': groupId, 'nombre': cleanName});
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw Exception('"$cleanName" already exists');
      rethrow;
    }
  }

  Future<void> deleteMember(String id) async {
    await _client.from('miembros').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getExpenses(String groupId) async {
    final res = await _client
        .from('gastos')
        .select('*, payer:miembros!gastos_pagado_por_id_fkey(nombre), participants:gastos_participantes(miembro_id, monto_a_pagar_cop, member:miembros(nombre))')
        .eq('parche_id', groupId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> addExpense({
    required String groupId,
    required String description,
    required double amount,
    required String currency,
    required String paidById,
    required List<String> participantIds,
    required double exchangeRate,
    Map<String, int>? customAmountsCop,
  }) async {
    final amountInCop = (amount * exchangeRate).toInt();

    final expense = await _client.from('gastos').insert({
      'parche_id': groupId,
      'descripcion': description,
      'monto_original': amount,
      'moneda': currency,
      'monto_cop': amountInCop,
      'tasa_cambio': exchangeRate,
      'fecha_tasa': DateTime.now().toIso8601String().substring(0, 10),
      'pagado_por_id': paidById,
      'quien_pago': '',
      'categoria': 'general',
    }).select().single();

    await _insertParticipants(expenseId: expense['id'] as String, amountInCop: amountInCop, participantIds: participantIds, customAmountsCop: customAmountsCop);
  }

  Future<void> updateExpense({
    required String expenseId,
    required String description,
    required double amount,
    required String currency,
    required String paidById,
    required List<String> participantIds,
    required double exchangeRate,
    Map<String, int>? customAmountsCop,
  }) async {
    final amountInCop = (amount * exchangeRate).toInt();

    await _client.from('gastos').update({
      'descripcion': description,
      'monto_original': amount,
      'moneda': currency,
      'monto_cop': amountInCop,
      'tasa_cambio': exchangeRate,
      'fecha_tasa': DateTime.now().toIso8601String().substring(0, 10),
      'pagado_por_id': paidById,
    }).eq('id', expenseId);

    // Re-create participants (simplest and safe)
    await _client.from('gastos_participantes').delete().eq('gasto_id', expenseId);
    await _insertParticipants(expenseId: expenseId, amountInCop: amountInCop, participantIds: participantIds, customAmountsCop: customAmountsCop);
  }

  Future<void> _insertParticipants({
    required String expenseId,
    required int amountInCop,
    required List<String> participantIds,
    Map<String, int>? customAmountsCop,
  }) async {
    List<Map<String, dynamic>> rows;
    if (customAmountsCop != null && customAmountsCop.isNotEmpty) {
      // Unequal division - use provided amounts
      rows = customAmountsCop.entries.map((e) => {
            'gasto_id': expenseId,
            'miembro_id': e.key,
            'monto_a_pagar_cop': e.value,
          }).toList();
    } else {
      // Equal division
      final perPerson = (amountInCop / participantIds.length).floor();
      final remainder = amountInCop - (perPerson * participantIds.length);
      rows = participantIds.asMap().entries.map((entry) {
        final idx = entry.key;
        final memberId = entry.value;
        return {
          'gasto_id': expenseId,
          'miembro_id': memberId,
          'monto_a_pagar_cop': perPerson + (idx == 0 ? remainder : 0),
        };
      }).toList();
    }
    await _client.from('gastos_participantes').insert(rows);
  }

  Future<void> deleteExpense(String id) async {
    await _client.from('gastos').delete().eq('id', id);
  }

  Future<Map<String, dynamic>> calculateDetailedBalance(String groupId) async {
    final members = await getMembers(groupId);
    final expenses = await _client.from('gastos').select().eq('parche_id', groupId);
    final participants = await _client.from('gastos_participantes').select('*, expense:gastos!inner(parche_id)').eq('expense.parche_id', groupId);

    final paid = <String, int>{};
    final owed = <String, int>{};
    final idToName = {for (var m in members) m['id'] as String: m['nombre'] as String};

    for (final m in members) {
      paid[m['id'] as String] = 0;
      owed[m['id'] as String] = 0;
    }

    for (final g in expenses) {
      final payerId = g['pagado_por_id'] as String?;
      if (payerId != null && paid.containsKey(payerId)) {
        paid[payerId] = paid[payerId]! + (g['monto_cop'] as int);
      }
    }

    for (final p in participants) {
      final memberId = p['miembro_id'] as String;
      if (owed.containsKey(memberId)) {
        owed[memberId] = owed[memberId]! + (p['monto_a_pagar_cop'] as int);
      }
    }

    final balanceById = <String, int>{};
    for (final id in paid.keys) {
      balanceById[id] = paid[id]! - owed[id]!;
    }

    final balanceByName = <String, int>{};
    for (final entry in balanceById.entries) {
      balanceByName[idToName[entry.key] ?? entry.key] = entry.value;
    }

    final debtors = balanceById.entries.where((e) => e.value < 0).toList()..sort((a, b) => a.value.compareTo(b.value));
    final creditors = balanceById.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));

    final transfers = <Map<String, dynamic>>[];
    int i = 0, j = 0;
    final debtorsCopy = debtors.map((e) => MapEntry(e.key, e.value)).toList();
    final creditorsCopy = creditors.map((e) => MapEntry(e.key, e.value)).toList();

    while (i < debtorsCopy.length && j < creditorsCopy.length) {
      final debtor = debtorsCopy[i];
      final creditor = creditorsCopy[j];
      final amount = (-debtor.value).clamp(0, creditor.value);
      if (amount > 0) {
        transfers.add({'from': idToName[debtor.key], 'to': idToName[creditor.key], 'amount': amount});
        debtorsCopy[i] = MapEntry(debtor.key, debtor.value + amount);
        creditorsCopy[j] = MapEntry(creditor.key, creditor.value - amount);
      }
      if (debtorsCopy[i].value == 0) i++;
      if (creditorsCopy[j].value == 0) j++;
    }

    return {'balance': balanceByName, 'transfers': transfers};
  }
}
