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

  @override
  void initState() {
    super.initState();
    _repo = ParchesRepository(Supabase.instance.client);
    // Deduplica por ID
    if (widget.miembros.isNotEmpty) {
      _pagadoPorId = widget.miembros.first['id'] as String;
    }
  }

  @override
  Widget build(BuildContext context) {
    final miembrosMap = <String, Map<String, dynamic>>{};
    for (final m in widget.miembros) {
      miembrosMap[m['id'] as String] = m;
    }
    final miembrosUnicos = miembrosMap.values.toList();

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Añadir gasto', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Descripción (ej: Pizza)')),
          TextField(controller: _montoCtrl, decoration: const InputDecoration(labelText: 'Monto'), keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          if (miembrosUnicos.isNotEmpty)
            DropdownButtonFormField<String>(
              value: miembrosUnicos.any((m) => m['id'] == _pagadoPorId) ? _pagadoPorId : null,
              decoration: const InputDecoration(labelText: '¿Quién pagó?'),
              items: miembrosUnicos
                  .map((m) => DropdownMenuItem<String>(value: m['id'] as String, child: Text(m['nombre'] as String)))
                  .toList(),
              onChanged: (v) => setState(() => _pagadoPorId = v),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _moneda,
            decoration: const InputDecoration(labelText: 'Moneda'),
            items: const [
              DropdownMenuItem(value: 'COP', child: Text('COP')),
              DropdownMenuItem(value: 'USD', child: Text('USD')),
              DropdownMenuItem(value: 'THB', child: Text('THB')),
              DropdownMenuItem(value: 'VND', child: Text('VND')),
            ],
            onChanged: (v) => setState(() => _moneda = v ?? 'COP'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              if (_descCtrl.text.isEmpty || _montoCtrl.text.isEmpty || _pagadoPorId == null) return;
              final monto = double.tryParse(_montoCtrl.text.replaceAll(',', '.'));
              if (monto == null) return;
              final pagador = miembrosUnicos.firstWhere((m) => m['id'] == _pagadoPorId);
              await _repo.addGasto(
                parcheId: widget.parcheId,
                descripcion: _descCtrl.text,
                monto: monto,
                moneda: _moneda,
                pagadoPor: pagador['nombre'] as String,
                pagadoPorId: _pagadoPorId!,
              );
              if (mounted) Navigator.pop(context, true);
            },
            child: const Text('Guardar gasto'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
