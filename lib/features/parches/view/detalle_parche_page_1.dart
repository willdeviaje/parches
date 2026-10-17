import 'package:flutter/material.dart';
import '../data/parches_repository.dart';
import '../../gastos/logic/balance_calculator.dart';
import 'add_gasto_sheet.dart';

class DetalleParchePage extends StatefulWidget {
  final String parcheId;
  final String nombre;
  const DetalleParchePage({super.key, required this.parcheId, required this.nombre});
  @override
  State<DetalleParchePage> createState() => _DetalleParchePageState();
}

class _DetalleParchePageState extends State<DetalleParchePage> {
  final repo = ParchesRepository();

  Future<void> _addMiembro() async {
    final ctrl = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Añadir miembro'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Ej: William, Ana, Juan')),
        actions: [TextButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Añadir'))],
      ),
    );
    if (nombre != null && nombre.isNotEmpty) {
      await repo.addMiembro(widget.parcheId, nombre);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.nombre)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: repo.watchGastos(widget.parcheId),
              builder: (context, gastosSnap) {
                final gastos = gastosSnap.data ?? [];
                final total = gastos.fold<int>(0, (s, g) => s + (g['monto_cop'] as int));
                return Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total gastado', style: TextStyle(fontSize: 16)),
                        Text('\$$total COP', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Miembros', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                TextButton.icon(onPressed: _addMiembro, icon: const Icon(Icons.person_add), label: const Text('Añadir')),
              ],
            ),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: repo.watchMiembros(widget.parcheId),
              builder: (context, snap) {
                final miembros = snap.data ?? [];
                if (miembros.isEmpty) return const Text('Añade miembros: William, Ana, Juan');
                return Wrap(
                  spacing: 8,
                  children: miembros.map((m) => Chip(label: Text(m['nombre']))).toList(),
                );
              },
            ),
            const SizedBox(height: 20),
            const Text('Balance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: repo.watchMiembros(widget.parcheId),
              builder: (context, miembrosSnap) {
                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: repo.watchGastos(widget.parcheId),
                  builder: (context, gastosSnap) {
                    final miembros = (miembrosSnap.data ?? []).map((e) => e['nombre'] as String).toList();
                    final gastos = gastosSnap.data ?? [];
                    if (miembros.length < 2 || gastos.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(12), child: Text('Añade gastos para ver quien debe qué')));
                    final deudas = BalanceCalculator.calcularBalance(miembros: miembros, gastos: gastos);
                    if (deudas.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(12), child: Text('¡Todo saldado!')));
                    return Column(
                      children: deudas.map((d) => Card(child: ListTile(
                        leading: const Icon(Icons.arrow_forward),
                        title: Text('${d.deudor} debe a ${d.acreedor}'),
                        trailing: Text('\$${d.montoCop}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ))).toList(),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            const Text('Gastos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: repo.watchGastos(widget.parcheId),
              builder: (context, snap) {
                final gastos = snap.data ?? [];
                if (gastos.isEmpty) return const Padding(padding: EdgeInsets.only(top:8), child: Text('Sin gastos aún'));
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: gastos.length,
                  itemBuilder: (_, i) {
                    final g = gastos[i];
                    return ListTile(
                      title: Text(g['descripcion']),
                      subtitle: Text('${g['quien_pago']} • ${g['monto_original']} ${g['moneda']}'),
                      trailing: Text('\$${g['monto_cop']}'),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => AddGastoSheet(parcheId: widget.parcheId)),
        label: const Text('Añadir gasto'),
        icon: const Icon(Icons.attach_money),
      ),
    );
  }
}
