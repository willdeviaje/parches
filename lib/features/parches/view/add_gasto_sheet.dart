import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/parches_repository.dart';
import '../../../core/services/currency_service.dart';

class AddGastoSheet extends StatefulWidget {
  final String parcheId;
  final List<Map<String, dynamic>> miembros;
  final Map<String, dynamic>? gastoExistente;
  const AddGastoSheet({super.key, required this.parcheId, required this.miembros, this.gastoExistente});

  @override
  State<AddGastoSheet> createState() => _AddGastoSheetState();
}

class _AddGastoSheetState extends State<AddGastoSheet> {
  late final ParchesRepository _repo;
  final _currencyService = CurrencyService();
  final _descCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  String? _pagadoPorId;
  String _moneda = 'COP';
  double? _tasaActual;
  bool _cargandoTasa = false;
  Map<String, bool> _dividirEntre = {};
  bool _guardando = false;

  bool get esEdicion => widget.gastoExistente != null;

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

    if (widget.gastoExistente != null) {
      final g = widget.gastoExistente!;
      _descCtrl.text = g['descripcion'] ?? '';
      _montoCtrl.text = (g['monto_original'] ?? '').toString();
      _moneda = g['moneda'] ?? 'COP';
      _pagadoPorId = g['pagado_por_id'] as String? ?? g['pagador_id'] as String? ?? g['pagador']?['id'] as String? ?? _pagadoPorId;
      _tasaActual = (g['tasa_cambio'] as num?)?.toDouble() ?? 1;
      
      // Si es edición, también cargar participantes reales
      final participantes = g['participantes'] as List? ?? [];
      if (participantes.isNotEmpty) {
         _dividirEntre.updateAll((k, v) => false);
         for (var p in participantes) {
           final mid = p['miembro_id'] ?? p['miembro']?['id'];
           if (mid != null) _dividirEntre[mid as String] = true;
         }
      }
    }
    _cargarTasa();
  }

  Future<void> _cargarTasa({bool forzar = false}) async {
    if (esEdicion && !forzar && _tasaActual != null) return;
    setState(() => _cargandoTasa = true);
    try {
      final tasa = forzar
          ? await _currencyService.refreshRate(_moneda)
          : await _currencyService.getRateToCop(_moneda);
      if (mounted) setState(() { _tasaActual = tasa; });
    } finally {
      if (mounted) setState(() => _cargandoTasa = false);
    }
  }

  double get _montoCopCalculado {
    final monto = double.tryParse(_montoCtrl.text.replaceAll(',', '.')) ?? 0;
    return monto * (_tasaActual ?? 1);
  }

  Future<void> _guardar() async {
    if (_descCtrl.text.trim().isEmpty || _montoCtrl.text.isEmpty || _pagadoPorId == null) return;
    final monto = double.tryParse(_montoCtrl.text.replaceAll(',', '.'));
    if (monto == null || monto <= 0) return;
    final participantesIds = _dividirEntre.entries.where((e) => e.value).map((e) => e.key).toList();
    if (participantesIds.isEmpty) return;

    setState(() => _guardando = true);
    try {
      if (esEdicion) {
        await _repo.updateGasto(
          gastoId: widget.gastoExistente!['id'],
          descripcion: _descCtrl.text.trim(),
          monto: monto,
          moneda: _moneda,
          pagadoPorId: _pagadoPorId!,
          participantesIds: participantesIds,
          tasaCambio: _tasaActual ?? 1,
        );
      } else {
        await _repo.addGasto(
          parcheId: widget.parcheId,
          descripcion: _descCtrl.text.trim(),
          monto: monto,
          moneda: _moneda,
          pagadoPorId: _pagadoPorId!,
          participantesIds: participantesIds,
          tasaCambio: _tasaActual ?? 1,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _guardando = false);
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
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(esEdicion ? 'Editar gasto' : 'Añadir gasto', style: Theme.of(context).textTheme.titleLarge),
              IconButton(onPressed: () => _cargarTasa(forzar: true), icon: const Icon(Icons.refresh), tooltip: 'Actualizar tasa'),
            ]),
            const SizedBox(height: 12),
            TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(flex: 2, child: TextField(controller: _montoCtrl, decoration: const InputDecoration(labelText: 'Monto', border: OutlineInputBorder()), keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _moneda,
                    decoration: const InputDecoration(labelText: 'Moneda', border: OutlineInputBorder()),
                    items: CurrencyService.monedasSoportadas.map((m) => DropdownMenuItem<String>(value: m['code'] as String, child: Text("${m['flag']} ${m['code']}"))).toList(),
                    onChanged: (v) async {
                      if (v != null) {
                        setState(() => _moneda = v);
                        await _cargarTasa(forzar: true);
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
              child: _cargandoTasa
                  ? const Row(children: [SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 8), Text('Buscando tasa en vivo...')])
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text('1 $_moneda = ${_tasaActual?.toStringAsFixed(2)} COP', style: const TextStyle(fontWeight: FontWeight.bold))),
                        Text('≈ \$${_montoCopCalculado.toStringAsFixed(0)} COP', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                      ],
                    ),
            ),
            const SizedBox(height: 6),
            Text('Fuente: open.er-api.com • Actualizado al cambiar moneda', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _pagadoPorId,
              decoration: const InputDecoration(labelText: '¿Quién pagó?', border: OutlineInputBorder()),
              items: widget.miembros.map((m) => DropdownMenuItem<String>(value: m['id'] as String, child: Text(m['nombre']))).toList(),
              onChanged: (v) => setState(() => _pagadoPorId = v),
            ),
            const SizedBox(height: 16),
            const Text('Dividir entre:', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(children: [TextButton(onPressed: () => setState(() => _dividirEntre.updateAll((k, v) => true)), child: const Text('Todos')), TextButton(onPressed: () => setState(() => _dividirEntre.updateAll((k, v) => false)), child: const Text('Ninguno'))]),
            ...widget.miembros.map((m) {
              final id = m['id'] as String;
              return CheckboxListTile(value: _dividirEntre[id] ?? false, title: Text(m['nombre']), controlAffinity: ListTileControlAffinity.leading, onChanged: (v) => setState(() => _dividirEntre[id] = v ?? false));
            }),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _guardando ? null : _guardar, child: _guardando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(esEdicion ? 'Actualizar gasto' : 'Guardar gasto')),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}