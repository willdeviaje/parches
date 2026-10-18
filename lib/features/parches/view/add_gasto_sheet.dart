import 'package:flutter/material.dart';
import '../data/parches_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../gastos/logic/balance_calculator.dart';

class AddGastoSheet extends StatefulWidget {
  final String parcheId;
  const AddGastoSheet({super.key, required this.parcheId});
  @override
  State<AddGastoSheet> createState() => _AddGastoSheetState();
}

class _AddGastoSheetState extends State<AddGastoSheet> {
  final repo = ParchesRepository(Supabase.instance.client);
  final descCtrl = TextEditingController();
  final montoCtrl = TextEditingController();
  String moneda = 'COP';
  String? quienPago;
  List<String> miembrosNombres = [];
  
  // Fase 3 - división desigual por montos
  bool divisionDesigual = false;
  Map<String, TextEditingController> divisionCtrls = {};

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
      for (var n in miembrosNombres) {
        divisionCtrls[n] = TextEditingController();
      }
    });
  }

  @override
  void dispose() {
    descCtrl.dispose();
    montoCtrl.dispose();
    for (var c in divisionCtrls.values) c.dispose();
    super.dispose();
  }

  int _totalDivisionMontos() {
    int total = 0;
    for (var ctrl in divisionCtrls.values) {
      final v = int.tryParse(ctrl.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
      total += v;
    }
    return total;
  }

  Future<void> _guardar() async {
    if (descCtrl.text.isEmpty || montoCtrl.text.isEmpty || quienPago == null) return;
    final monto = num.tryParse(montoCtrl.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
    final montoCop = BalanceCalculator.toCop(monto, moneda);

    String divisionTipo = 'igual';
    List<Map<String, dynamic>>? divisionData;

    if (divisionDesigual) {
      divisionTipo = 'montos';
      divisionData = [];
      for (var nombre in miembrosNombres) {
        final ctrl = divisionCtrls[nombre];
        final val = int.tryParse(ctrl?.text.replaceAll('.', '').replaceAll(',', '') ?? '0') ?? 0;
        divisionData.add({'nombre': nombre, 'monto_cop': val});
      }
      final suma = divisionData.fold<int>(0, (s, e) => s + (e['monto_cop'] as int));
      if (suma != montoCop) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('La suma desigual (\$$suma) debe ser igual al total (\$$montoCop)')),
        );
        return;
      }
    }

    await repo.addGasto(
      parcheId: widget.parcheId,
      descripcion: descCtrl.text,
      montoOriginal: monto,
      moneda: moneda,
      quienPago: quienPago!,
      divisionTipo: divisionTipo,
      divisionData: divisionData,
    );
    if (mounted) Navigator.pop(context);
  }

  void _repartirIgual() {
    if (miembrosNombres.isEmpty) return;
    final monto = int.tryParse(montoCtrl.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
    if (monto == 0) return;
    final montoCop = BalanceCalculator.toCop(monto, moneda);
    final porPersona = montoCop ~/ miembrosNombres.length;
    final resto = montoCop % miembrosNombres.length;
    setState(() {
      for (int i = 0; i < miembrosNombres.length; i++) {
        final n = miembrosNombres[i];
        divisionCtrls[n]?.text = (porPersona + (i == 0 ? resto : 0)).toString();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalDivision = _totalDivisionMontos();
    final montoIngresado = int.tryParse(montoCtrl.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
    final montoCopIngresado = BalanceCalculator.toCop(montoIngresado, moneda);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nuevo gasto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Descripcion Ej: Cena 100k')),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: TextField(controller: montoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Monto'), onChanged: (_) => setState(() {}))),
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
              decoration: const InputDecoration(labelText: 'Quien pago'),
              items: miembrosNombres.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
              onChanged: (v) => setState(() => quienPago = v),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Division desigual por montos'),
              subtitle: Text(divisionDesigual ? 'Ej: Will \$80k / Karoll \$20k' : 'Reparto igual (MVP1)'),
              value: divisionDesigual,
              onChanged: (v) => setState(() => divisionDesigual = v),
            ),
            if (divisionDesigual) ...[
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Reparto (Total: \$$montoCopIngresado COP)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  TextButton(onPressed: _repartirIgual, child: const Text('Repartir igual')),
                ],
              ),
              ...miembrosNombres.map((nombre) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(width: 80, child: Text(nombre, style: const TextStyle(fontWeight: FontWeight.w500))),
                    Expanded(
                      child: TextField(
                        controller: divisionCtrls[nombre],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Monto \$nombre',
                          prefixText: '\$ ',
                          suffixText: 'COP',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 4),
              Text(
                'Suma: \$$totalDivision / Total: \$$montoCopIngresado \${totalDivision == montoCopIngresado ? "OK" : "Debe coincidir"}',
                style: TextStyle(fontSize: 12, color: totalDivision == montoCopIngresado ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: _guardar, child: const Text('Guardar gasto'))),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
