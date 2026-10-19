import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/group_repository.dart';
import '../../../core/services/currency_service.dart';

class AddExpenseSheet extends StatefulWidget {
  final String groupId;
  final List<Map<String, dynamic>> members;
  const AddExpenseSheet({super.key, required this.groupId, required this.members});

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  late final GroupRepository _repo;
  final _currencyService = CurrencyService();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  String? _paidById;
  String _currency = 'COP';
  double? _currentRate;
  bool _loadingRate = false;
  final Map<String, bool> _splitBetween = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _repo = GroupRepository(Supabase.instance.client);
    for (final m in widget.members) {
      _splitBetween[m['id'] as String] = true;
    }
    if (widget.members.isNotEmpty) {
      _paidById = widget.members.first['id'] as String;
    }
    _loadRate();
  }

  Future<void> _loadRate({bool force = false}) async {
    setState(() => _loadingRate = true);
    try {
      final rate = force
          ? await _currencyService.refreshRate(_currency)
          : await _currencyService.getRateToCop(_currency);
      if (mounted) {
        setState(() => _currentRate = rate);
      }
    } finally {
      if (mounted) setState(() => _loadingRate = false);
    }
  }

  double get _amountInCop {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;
    return amount * (_currentRate ?? 1);
  }

  Future<void> _save() async {
    if (_descController.text.trim().isEmpty || _amountController.text.isEmpty || _paidById == null) return;
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) return;
    final participantIds = _splitBetween.entries.where((e) => e.value).map((e) => e.key).toList();
    if (participantIds.isEmpty) return;

    setState(() => _saving = true);
    try {
      await _repo.addExpense(
        groupId: widget.groupId,
        description: _descController.text.trim(),
        amount: amount,
        currency: _currency,
        paidById: _paidById!,
        participantIds: participantIds,
        exchangeRate: _currentRate ?? 1,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Añadir gasto', style: Theme.of(context).textTheme.titleLarge),
                IconButton(onPressed: () => _loadRate(force: true), icon: const Icon(Icons.refresh), tooltip: 'Actualizar tasa'),
              ],
            ),
            const SizedBox(height: 12),
            TextField(controller: _descController, decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _amountController,
                    decoration: const InputDecoration(labelText: 'Monto', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _currency,
                    decoration: const InputDecoration(labelText: 'Moneda', border: OutlineInputBorder()),
                    items: CurrencyService.monedasSoportadas
                        .map((m) => DropdownMenuItem<String>(value: m['code'] as String, child: Text("${m['flag']} ${m['code']}")))
                        .toList(),
                    onChanged: (v) async {
                      if (v != null) {
                        setState(() => _currency = v);
                        await _loadRate(force: true);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: _loadingRate
                  ? const Row(children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text('Buscando tasa en vivo...')
                    ])
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text('1 $_currency = ${_currentRate?.toStringAsFixed(2)} COP', style: const TextStyle(fontWeight: FontWeight.bold))),
                        Text('≈ \$${_amountInCop.toStringAsFixed(0)} COP', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                      ],
                    ),
            ),
            const SizedBox(height: 6),
            Text('Fuente: open.er-api.com • Actualizado al cambiar moneda', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _paidById,
              decoration: const InputDecoration(labelText: '¿Quién pagó?', border: OutlineInputBorder()),
              items: widget.members.map((m) => DropdownMenuItem<String>(value: m['id'] as String, child: Text(m['nombre']))).toList(),
              onChanged: (v) => setState(() => _paidById = v),
            ),
            const SizedBox(height: 16),
            const Text('Dividir entre:', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                TextButton(onPressed: () => setState(() => _splitBetween.updateAll((k, v) => true)), child: const Text('Todos')),
                TextButton(onPressed: () => setState(() => _splitBetween.updateAll((k, v) => false)), child: const Text('Ninguno')),
              ],
            ),
            ...widget.members.map((m) {
              final id = m['id'] as String;
              return CheckboxListTile(
                value: _splitBetween[id] ?? false,
                title: Text(m['nombre']),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (v) => setState(() => _splitBetween[id] = v ?? false),
              );
            }),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const CircularProgressIndicator() : const Text('Guardar gasto'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
