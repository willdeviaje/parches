import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/parches_repository.dart';
import 'add_gasto_sheet.dart';
import '../../../core/services/currency_service.dart';

class DetalleParchePage extends StatefulWidget {
  final Map<String, dynamic> parche;
  const DetalleParchePage({super.key, required this.parche});

  @override
  State<DetalleParchePage> createState() => _DetalleParchePageState();
}

class _DetalleParchePageState extends State<DetalleParchePage> {
  late final ParchesRepository _repo;
  List<Map<String, dynamic>> _miembros = [];
  List<Map<String, dynamic>> _gastos = [];
  Map<String, int> _balance = {};
  List<Map<String, dynamic>> _transferencias = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo = ParchesRepository(Supabase.instance.client);
    _cargarTodo();
  }

  String _simbolo(String code) {
    return CurrencyService.monedasSoportadas.firstWhere(
      (m) => m['code'] == code,
      orElse: () => {'symbol': code},
    )['symbol'] as String;
  }

  String _formatCOP(int v) {
    if (v == 0) return '0';
    final abs = v.abs();
    final str = abs.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return v < 0 ? '-$str' : str;
  }

  Future<void> _cargarTodo() async {
    setState(() => _loading = true);
    try {
      final miembros = await _repo.getMiembros(widget.parche['id']);
      final gastos = await _repo.getGastos(widget.parche['id']);
      final balanceData = await _repo.calcularBalanceDetallado(widget.parche['id']);
      if (mounted) {
        setState(() {
          _miembros = miembros;
          _gastos = gastos;
          _balance = Map<String, int>.from(balanceData['balance'] as Map);
          _transferencias = List<Map<String, dynamic>>.from(balanceData['transferencias'] as List);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _mostrarAddMiembro() async {
    final ctrl = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Añadir miembro'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: 'Ej: William, Ana')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('Añadir'))
        ],
      ),
    );
    if (nombre == null || nombre.isEmpty) return;
    try {
      await _repo.addMiembro(parcheId: widget.parche['id'], nombre: nombre);
      await _cargarTodo();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _confirmarBorrarMiembro(Map<String, dynamic> m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('¿Borrar ${m['nombre']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Borrar'))
        ],
      ),
    );
    if (ok == true) {
      await _repo.deleteMiembro(m['id']);
      await _cargarTodo();
    }
  }

  Future<void> _confirmarBorrarGasto(Map<String, dynamic> g) async {
    final desc = g['descripcion'] ?? '';
    final montoOrig = g['monto_original']?.toString() ?? g['monto_cop']?.toString() ?? '0';
    final moneda = g['moneda'] ?? 'COP';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Borrar gasto?'),
        content: Text('$desc - $montoOrig $moneda'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Borrar'))
        ],
      ),
    );
    if (ok == true) {
      await _repo.deleteGasto(g['id']);
      await _cargarTodo();
    }
  }

  Future<void> _confirmarBorrarParche() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Borrar parche?'),
        content: Text('Se borrará "${widget.parche['nombre']}"'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Borrar'),
          )
        ],
      ),
    );
    if (ok == true) {
      await _repo.deleteParche(widget.parche['id']);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _gastos.fold<int>(0, (sum, g) => sum + ((g['monto_cop'] as int?) ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.parche['nombre']),
        actions: [IconButton(icon: const Icon(Icons.delete_forever), onPressed: _confirmarBorrarParche)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarTodo,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total gastado'),
                            Text('${_gastos.length} gastos', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))
                          ],
                        ),
                        Text('\$${_formatCOP(total)} COP', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Miembros', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton.icon(onPressed: _mostrarAddMiembro, icon: const Icon(Icons.person_add), label: const Text('Añadir'))
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_miembros.isEmpty)
                    const Text('Añade miembros')
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _miembros
                          .map((m) => Chip(
                                label: Text(m['nombre']),
                                deleteIcon: const Icon(Icons.close, size: 18),
                                onDeleted: () => _confirmarBorrarMiembro(m),
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
                      final esPositivo = e.value > 0;
                      final esCero = e.value == 0;
                      Color bgColor;
                      Color textColor;
                      String subtitle;
                      if (esCero) {
                        bgColor = Colors.grey.shade100;
                        textColor = Colors.grey.shade700;
                        subtitle = 'A paz y salvo';
                      } else if (esPositivo) {
                        bgColor = Colors.green.shade50;
                        textColor = Colors.green.shade700;
                        subtitle = 'Le deben';
                      } else {
                        bgColor = Colors.red.shade50;
                        textColor = Colors.red.shade700;
                        subtitle = 'Debe';
                      }
                      return Card(
                        color: bgColor,
                        child: ListTile(
                          title: Text(e.key),
                          subtitle: Text(subtitle),
                          trailing: Text(
                            esCero ? '\$0' : '${esPositivo ? '+' : ''}\$${_formatCOP(e.value)}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                          ),
                        ),
                      );
                    }),
                  if (_transferencias.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Para saldar:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._transferencias.map((t) => Card(
                          color: Colors.blue.shade50,
                          child: ListTile(
                            leading: const Icon(Icons.swap_horiz),
                            title: Text("${t['de']} → ${t['a']}"),
                            trailing: Text("\$${_formatCOP(t['monto'] as int)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        )),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Gastos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Text('Toca para editar', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_gastos.isEmpty)
                    const Text('Sin gastos aún')
                  else
                    ..._gastos.map((g) {
                      final desc = g['descripcion'] as String? ?? '';
                      final pagadorNombre = g['pagador']?['nombre'] as String? ?? 'Desconocido';
                      final moneda = g['moneda'] as String? ?? 'COP';
                      final montoOrig = (g['monto_original'] as num?)?.toDouble() ?? 0;
                      final montoCop = g['monto_cop'] as int? ?? 0;
                      final tasa = (g['tasa_cambio'] as num?)?.toDouble() ?? 1;
                      final esCop = moneda == 'COP';

                      final subtitle = esCop
                          ? "$pagadorNombre • \$${_formatCOP(montoCop)} COP"
                          : "$pagadorNombre • ${montoOrig.toStringAsFixed(montoOrig % 1 == 0 ? 0 : 2)} $moneda → \$${_formatCOP(montoCop)} COP • Tasa: ${tasa.toStringAsFixed(2)}";

                      return Card(
                        child: ListTile(
                          onTap: () async {
                            final result = await showModalBottomSheet<bool>(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) => AddGastoSheet(
                                parcheId: widget.parche['id'],
                                miembros: _miembros,
                                gastoExistente: g,
                              ),
                            );
                            if (result == true) await _cargarTodo();
                          },
                          title: Text(desc, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(subtitle),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!esCop)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(8)),
                                  child: Text(moneda, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                onPressed: () => _confirmarBorrarGasto(g),
                              )
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (_miembros.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Primero añade un miembro')));
            return;
          }
          final result = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            builder: (_) => AddGastoSheet(parcheId: widget.parche['id'], miembros: _miembros),
          );
          if (result == true) await _cargarTodo();
        },
        label: const Text('Añadir gasto'),
        icon: const Icon(Icons.attach_money),
      ),
    );
  }
}