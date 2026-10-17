import 'package:flutter/material.dart';
import '../data/parches_repository.dart';

class AddGastoSheet extends StatefulWidget {
  final String parcheId;
  const AddGastoSheet({super.key, required this.parcheId});
  @override
  State<AddGastoSheet> createState() => _AddGastoSheetState();
}

class _AddGastoSheetState extends State<AddGastoSheet> {
  final repo = ParchesRepository();
  final descCtrl = TextEditingController();
  final montoCtrl = TextEditingController();
  String moneda = 'COP';
  String? quienPago;
  List<String> miembrosNombres = [];

  @override
  void initState() {
    super.initState();
    _loadMiembros();
  }

  Future<void> _loadMiembros() async {
    final miembros = await repo.client.from('miembros').select('nombre').eq('parche_id', widget.parcheId);
    setState(() {
      miembrosNombres = (miembros as List).map((e) => e['nombre'] as String).toList();
      if (miembrosNombres.isNotEmpty) quienPago = miembrosNombres.first;
    });
  }

  Future<void> _guardar() async {
    if (descCtrl.text.isEmpty || montoCtrl.text.isEmpty || quienPago == null) return;
    final monto = num.tryParse(montoCtrl.text.replaceAll(',', '')) ?? 0;
    await repo.addGasto(
      parcheId: widget.parcheId,
      descripcion: descCtrl.text,
      montoOriginal: monto,
      moneda: moneda,
      quienPago: quienPago!,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Nuevo gasto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Descripción Ej: Pizza')),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: TextField(controller: montoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Monto'))),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: moneda,
                items: ['COP','THB','VND','USD'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => setState(() => moneda = v!),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: quienPago,
            decoration: const InputDecoration(labelText: 'Quién pagó'),
            items: miembrosNombres.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
            onChanged: (v) => setState(() => quienPago = v),
          ),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: _guardar, child: const Text('Guardar gasto'))),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
