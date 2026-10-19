import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/group_repository.dart';
import 'add_expense_sheet.dart';

class GroupDetailPage extends StatefulWidget {
  final Map<String, dynamic> group;
  const GroupDetailPage({super.key, required this.group});

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  late final GroupRepository _repo;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _expenses = [];
  Map<String, int> _balance = {};
  List<Map<String, dynamic>> _transfers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo = GroupRepository(Supabase.instance.client);
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final members = await _repo.getMembers(widget.group['id']);
      final expenses = await _repo.getExpenses(widget.group['id']);
      final balanceData = await _repo.calculateDetailedBalance(widget.group['id']);

      if (mounted) {
        setState(() {
          _members = members;
          _expenses = expenses;
          _balance = Map<String, int>.from(balanceData['balance'] as Map);
          _transfers = List<Map<String, dynamic>>.from(balanceData['transfers'] as List);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showAddMember() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Añadir miembro'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: 'Ej: William, Ana')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('Añadir')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await _repo.addMember(groupId: widget.group['id'], name: name);
      await _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmDeleteMember(Map<String, dynamic> member) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('¿Borrar ${member['nombre']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Borrar')),
        ],
      ),
    );
    if (ok == true) {
      await _repo.deleteMember(member['id']);
      await _loadAll();
    }
  }

  Future<void> _showExpenseSheet({Map<String, dynamic>? expense}) async {
    if (_members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Primero añade un miembro')));
      return;
    }
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddExpenseSheet(groupId: widget.group['id'], members: _members, existingExpense: expense),
    );
    if (result == true) await _loadAll();
  }

  Future<void> _confirmDeleteExpense(Map<String, dynamic> expense) async {
    final amount = expense['monto_original'] ?? expense['monto_cop'] ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Borrar gasto?'),
        content: Text('${expense['descripcion']} - $amount'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Borrar')),
        ],
      ),
    );
    if (ok == true) {
      await _repo.deleteExpense(expense['id']);
      await _loadAll();
    }
  }

  Future<void> _confirmDeleteGroup() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Borrar parche?'),
        content: Text('Se borrará "${widget.group['nombre']}"'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _repo.deleteGroup(widget.group['id']);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _expenses.fold<int>(0, (sum, g) => sum + ((g['monto_cop'] ?? g['monto_original'] ?? 0) as int));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group['nombre']),
        actions: [IconButton(icon: const Icon(Icons.delete_forever), onPressed: _confirmDeleteGroup)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total gastado'),
                        Text('\$$total COP', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Miembros', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton.icon(onPressed: _showAddMember, icon: const Icon(Icons.person_add), label: const Text('Añadir')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_members.isEmpty)
                    const Text('Añade miembros')
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _members
                          .map((m) => Chip(
                                label: Text(m['nombre']),
                                deleteIcon: const Icon(Icons.close, size: 18),
                                onDeleted: () => _confirmDeleteMember(m),
                              ))
                          .toList(),
                    ),
                  const SizedBox(height: 20),
                  const Text('Balance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_balance.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                      child: const Text('Añade gastos para ver quien debe qué'),
                    )
                  else
                    ..._balance.entries.map((e) {
                      final isPositive = e.value > 0;
                      return Card(
                        color: isPositive ? Colors.green.shade50 : Colors.red.shade50,
                        child: ListTile(
                          title: Text(e.key),
                          subtitle: Text(isPositive ? 'Le deben' : 'Debe'),
                          trailing: Text(
                            '${isPositive ? '+' : ''}\$${e.value}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: isPositive ? Colors.green : Colors.red),
                          ),
                        ),
                      );
                    }),
                  if (_transfers.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Para saldar:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._transfers.map(
                      (t) => Card(
                        color: Colors.blue.shade50,
                        child: ListTile(
                          leading: const Icon(Icons.swap_horiz),
                          title: Text("${t['from']} → ${t['to']}"),
                          trailing: Text("\$${t['amount']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Gastos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Toca para editar', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_expenses.isEmpty)
                    const Text('Sin gastos aún')
                  else
                    ..._expenses.map((g) {
                      final amount = g['monto_cop'] ?? g['monto_original'] ?? 0;
                      final payerName = g['payer']?['nombre'] ?? 'Desconocido';
                      final isUnequal = (g['participants'] as List?)?.map((p) => p['monto_a_pagar_cop']).toSet().length != 1;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _showExpenseSheet(expense: g),
                          child: ListTile(
                            title: Text(g['descripcion'] ?? ''),
                            subtitle: Text("$payerName • $amount ${g['moneda']}${isUnequal ? ' • desigual' : ''}"),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("\$$amount"),
                                IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _confirmDeleteExpense(g)),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showExpenseSheet(),
        label: const Text('Añadir gasto'),
        icon: const Icon(Icons.attach_money),
      ),
    );
  }
}
