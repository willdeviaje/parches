import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/group_repository.dart';
import '../../../core/services/currency_service.dart';

class AddExpenseSheet extends StatefulWidget {
  final String groupId;
  final List<Map<String, dynamic>> members;
  final Map<String, dynamic>? existingExpense;

  const AddExpenseSheet({super.key, required this.groupId, required this.members, this.existingExpense});

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
  final Map<String, TextEditingController> _customAmountControllers = {};
  bool _isUnequal = false;
  bool _saving = false;

  bool get _isEditing => widget.existingExpense != null;

  @override
  void initState() {
    super.initState();
    _repo = GroupRepository(Supabase.instance.client);

    // Initialize members selection
    for (final m in widget.members) {
      final id = m['id'] as String;
      _splitBetween[id] = true;
      _customAmountControllers[id] = TextEditingController();
    }

    if (_isEditing) {
      final exp = widget.existingExpense!;
      _descController.text = exp['descripcion'] ?? '';
      _amountController.text = (exp['monto_original'] ?? '').toString();
      _currency = exp['moneda'] ?? 'COP';
      _paidById = exp['pagado_por_id'] as String?;
      // Participants
      final participants = exp['participants'] as List? ?? [];
      if (participants.isNotEmpty) {
        for (final id in _splitBetween.keys) {
          _splitBetween[id] = false;
        }
        for (final p in participants) {
          final memberId = p['miembro_id'] as String?;
          if (memberId != null && _splitBetween.containsKey(memberId)) {
            _splitBetween[memberId] = true;
            _customAmountControllers[memberId]?.text = (p['monto_a_pagar_cop'] ?? '').toString();
          }
        }
        // Detect if unequal
        if (participants.length > 1) {
          final amounts = participants.map((p) => p['monto_a_pagar_cop'] as int).toSet();
          if (amounts.length > 1) _isUnequal = true;
        }
      }
    } else {
      if (widget.members.isNotEmpty) {
        _paidById = widget.members.first['id'] as String;
      }
    }
    _loadRate();
  }

  @override
  void dispose() {
    for (final c in _customAmountControllers.values) {
      c.dispose();
    }
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadRate({bool force = false}) async {
    setState(() => _loadingRate = true);
    try {
      final rate = force ? await _currencyService.refreshRate(_currency) : await _currencyService.getRateToCop(_currency);
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

  int get _customTotal {
    int total = 0;
    for (final entry in _splitBetween.entries) {
      if (entry.value) {
        final txt = _customAmountControllers[entry.key]?.text ?? '';
        total += int.tryParse(txt) ?? 0;
      }
    }
    return total;
  }

  Future<void> _save() async {
    if (_descController.text.trim().isEmpty || _amountController.text.isEmpty || _paidById == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completa descripción, monto y quién pagó')));
      return;
    }
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) return;
    final participantIds = _splitBetween.entries.where((e) => e.value).map((e) => e.key).toList();
    if (participantIds.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona al menos un participante')));
      return;
    }

    Map<String, int>? customAmounts;
    if (_isUnequal) {
      customAmounts = {};
      for (final id in participantIds) {
        final txt = _customAmountControllers[id]?.text.trim() ?? '';
        final val = int.tryParse(txt);
        if (val == null || val < 0) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Montos desiguales inválidos')));
          return;
        }
        customAmounts[id] = val;
      }
      final sum = customAmounts.values.fold<int>(0, (a, b) => a + b);
      if (sum != _amountInCop.toInt()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('La suma desigual ($sum) debe ser igual al total (${_amountInCop.toInt()}) COP')));
        }
        return;
      }
    }

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await _repo.updateExpense(
          expenseId: widget.existingExpense!['id'] as String,
          description: _descController.text.trim(),
          amount: amount,
          currency: _currency,
          paidById: _paidById!,
          participantIds: participantIds,
          exchangeRate: _currentRate ?? 1,
          customAmountsCop: customAmounts,
        );
      } else {
        await _repo.addExpense(
          groupId: widget.groupId,
          description: _descController.text.trim(),
          amount: amount,
          currency: _currency,
          paidById: _paidById!,
          participantIds: participantIds,
          exchangeRate: _currentRate ?? 1,
          customAmountsCop: customAmounts,
        );
      }
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
                Text(_isEditing ? 'Editar gasto' : 'Añadir gasto', style: Theme.of(context).textTheme.titleLarge),
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
                    items: CurrencyService.monedasSoportadas.map((m) => DropdownMenuItem<String>(value: m['code'] as String, child: Text("${m['flag']} ${m['code']}"))).toList(),
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
                  ? const Row(children: [SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 8), Text('Buscando tasa en vivo...')])
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text('1 $_currency = ${_currentRate?.toStringAsFixed(2)} COP', style: const TextStyle(fontWeight: FontWeight.bold))),
                        Text('≈ \$${_amountInCop.toStringAsFixed(0)} COP', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _paidById,
              decoration: const InputDecoration(labelText: '¿Quién pagó?', border: OutlineInputBorder()),
              items: widget.members.map((m) => DropdownMenuItem<String>(value: m['id'] as String, child: Text(m['nombre']))).toList(),
              onChanged: (v) => setState(() => _paidById = v),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Dividir entre:', style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    TextButton(onPressed: () => setState(() => _splitBetween.updateAll((k, v) => true)), child: const Text('Todos')),
                    TextButton(onPressed: () => setState(() => _splitBetween.updateAll((k, v) => false)), child: const Text('Ninguno')),
                  ],
                ),
              ],
            ),
            SwitchListTile(
              title: const Text('División desigual'),
              subtitle: Text(_isUnequal ? 'Montos personalizados por persona' : 'Reparto igualitario'),
              value: _isUnequal,
              onChanged: (v) => setState(() => _isUnequal = v),
            ),
            ...widget.members.map((m) {
              final id = m['id'] as String;
              final selected = _splitBetween[id] ?? false;
              return Column(
                children: [
                  CheckboxListTile(
                    value: selected,
                    title: Text(m['nombre']),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (v) => setState(() => _splitBetween[id] = v ?? false),
                  ),
                  if (selected && _isUnequal)
                    Padding(
                      padding: const EdgeInsets.only(left: 72, right: 16, bottom: 8),
                      child: TextField(
                        controller: _customAmountControllers[id],
                        decoration: InputDecoration(labelText: 'Monto para ${m['nombre']} (COP)', border: const OutlineInputBorder(), prefixText: '\$ '),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                ],
              );
            }),
            if (_isUnequal) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _customTotal == _amountInCop.toInt() ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Suma personalizada: \$$_customTotal / \$${_amountInCop.toInt()} COP',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _customTotal == _amountInCop.toInt() ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_isEditing ? 'Actualizar gasto' : 'Guardar gasto'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
