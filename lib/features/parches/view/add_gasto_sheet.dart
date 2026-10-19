import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/parches_repository.dart';

class AddGastoSheet extends StatefulWidget {
  final String parcheId;
  final List<Map<String, dynamic>>? miembros;
  final Map<String, dynamic>? gastoExistente;
  const AddGastoSheet({super.key, required this.parcheId, this.miembros, this.gastoExistente});

  @override
  State<AddGastoSheet> createState() => _AddGastoSheetState();
}

class _AddGastoSheetState extends State<AddGastoSheet> {
  late final ParchesRepository _repo;
  final _descCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  String? _pagadoPorId;
  String _moneda = 'COP';
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _repo = ParchesRepository(Supabase.instance.client);
    _descCtrl.text = widget.gastoExistente?['descripcion'] ?? '';
    _montoCtrl.text = (widget.gastoExistente?['monto_original'] ?? '').toString();
    if ((widget.miembros ?? []).isNotEmpty) {
      _pagadoPorId = widget.miembros!.first['id'] as String;
    }
  }

  Future<void> _guardar() async {
    if (_descCtrl.text.trim().isEmpty || _montoCtrl.text.isEmpty) return;
    final monto = double.tryParse(_montoCtrl.text.replaceAll(',', '.'));
    if (monto == null) return;
    setState(() => _guardando = true);
    try {
      final miembros = widget.miembros ?? [];
      final pagador = miembros.isNotEmpty ? (miembros.firstWhere((m) => m['id'] == _pagadoPorId, orElse: () => miembros.first)['nombre'] as String) : 'Yo';
      await _repo.addGasto(
        parcheId: widget.parcheId,
        descripcion: _descCtrl.text.trim(),
        montoOriginal: monto,
        moneda: _moneda,
        quienPago: pagador,
      );
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final miembros = widget.miembros ?? [];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.gastoExistente == null ? 'Añadir gasto' : 'Editar gasto', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _montoCtrl, decoration: const InputDecoration(labelText: 'Monto', border: OutlineInputBorder()), keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          if (miembros.isNotEmpty)
            DropdownButtonFormField<String>(
              value: _pagadoPorId,
              decoration: const InputDecoration(labelText: '¿Quién pagó?', border: OutlineInputBorder()),
              items: miembros.map((m) => DropdownMenuItem<String>(value: m['id'] as String, child: Text(m['nombre'] as String))).toList(),
              onChanged: (v) => setState(() => _pagadoPorId = v),
            ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _guardando ? null : _guardar, child: Text(widget.gastoExistente == null ? 'Guardar' : 'Actualizar')),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}