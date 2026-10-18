import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/parches_repository.dart';

class AddGastoSheet extends StatefulWidget {
  final String parcheId;
  final List<Map<String, dynamic>> miembros;
  const AddGastoSheet({super.key, required this.parcheId, required this.miembros});

  @override
  State<AddGastoSheet> createState() => _AddGastoSheetState();
}

class _AddGastoSheetState extends State<AddGastoSheet> {
  late final ParchesRepository _repo;
  final _descCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  String? _pagadoPorId;
  String _moneda = 'COP';
  Map<String, bool> _dividirEntre = {};
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _repo = ParchesRepository(Supabase.instance.client);
    for (final m in widget.miembros) {
      _dividirEntre[m['id'] as String] = true;
    }
    if (widget.miembros.isNotEmpty) {
      _pagadoPorId = widget.miembros.first['id'] as String;
    }
  }

  Future<void> _guardar() async {
    if (_descCtrl.text.trim().isEmpty || _montoCtrl.text.isEmpty || _pagadoPorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completa descripción, monto y quien pagó')));
      return;
    }
    final monto = double.tryParse(_montoCtrl.text.replaceAll(',', '.'));
    if (monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Monto inválido')));
      return;
    }
    final participantesIds = _dividirEntre.entries.where((e) => e.value).map((e) => e.key).toList();
    if (participantesIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona al menos 1 persona para dividir')));
      return;
    }

    setState(() => _guardando = true);
    try {
      final pagador = widget.miembros.firstWhere((m) => m['id'] == _pagadoPorId);
      await _repo.addGasto(
        parcheId: widget.parcheId,
        descripcion: _descCtrl.text.trim(),
        monto: monto,
        moneda: _moneda,
        pagadoPor: pagador['nombre'] as String,
        pagadoPorId: _pagadoPorId!,
        participantesIds: participantesIds,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final miembrosUnicos = widget.miembros;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Añadir gasto', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Descripción (ej: Pizza, Taxi)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _montoCtrl, decoration: const InputDecoration(labelText: 'Monto', border: OutlineInputBorder()), keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            if (miembrosUnicos.isNotEmpty)
              DropdownButtonFormField<String>(
                value: miembrosUnicos.any((m) => m['id'] == _pagadoPorId) ? _pagadoPorId : null,
                decoration: const InputDecoration(labelText: '¿Quién pagó?', border: OutlineInputBorder()),
                items: miembrosUnicos.map((m) => DropdownMenuItem<String>(value: m['id'] as String, child: Text(m['nombre'] as String))).toList(),
                onChanged: (v) => setState(() => _pagadoPorId = v),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _moneda,
              decoration: const InputDecoration(labelText: 'Moneda', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'COP', child: Text('COP')),
                DropdownMenuItem(value: 'USD', child: Text('USD')),
                DropdownMenuItem(value: 'THB', child: Text('THB')),
                DropdownMenuItem(value: 'VND', child: Text('VND')),
              ],
              onChanged: (v) => setState(() => _moneda = v ?? 'COP'),
            ),
            const SizedBox(height: 16),
            const Text('Dividir entre:', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(children: [
              TextButton(onPressed: () => setState(() => _dividirEntre.updateAll((k, v) => true)), child: const Text('Todos')),
              TextButton(onPressed: () => setState(() => _dividirEntre.updateAll((k, v) => false)), child: const Text('Ninguno')),
            ]),
            ...miembrosUnicos.map((m) {
              final id = m['id'] as String;
              return CheckboxListTile(
                value: _dividirEntre[id] ?? false,
                title: Text(m['nombre'] as String),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (v) => setState(() => _dividirEntre[id] = v ?? false),
              );
            }),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _guardando ? null : _guardar, child: _guardando ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Guardar gasto')),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
