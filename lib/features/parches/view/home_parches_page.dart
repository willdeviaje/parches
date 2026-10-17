import 'package:flutter/material.dart';
import '../data/parches_repository.dart';
import 'detalle_parche_page.dart';

class HomeParchesPage extends StatefulWidget {
  const HomeParchesPage({super.key});
  @override
  State<HomeParchesPage> createState() => _HomeParchesPageState();
}

class _HomeParchesPageState extends State<HomeParchesPage> {
  final repo = ParchesRepository();
  late Future<List<Map<String, dynamic>>> _future;
  
  @override
  void initState() {
    super.initState();
    _future = repo.getParches();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = repo.getParches();
    });
  }

  Future<void> _crearParcheDialog() async {
    final ctrl = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuevo Parche'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: 'Ej: Pizza Mosquera')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Crear')),
        ],
      ),
    );
    if (nombre != null && nombre.isNotEmpty) {
      await repo.crearParche(nombre);
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Parches'), 
        centerTitle: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          final parches = snap.data ?? [];
          if (parches.isEmpty) {
            return const Center(child: Text('No hay parches.\nCrea el primero para dividir gastos.', textAlign: TextAlign.center));
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: parches.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final p = parches[i];
                return _ParcheCard(
                  nombre: p['nombre'],
                  id: p['id'],
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetalleParchePage(parcheId: p['id'], nombre: p['nombre']))).then((_) => _refresh()),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crearParcheDialog,
        label: const Text('Nuevo Parche'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _ParcheCard extends StatefulWidget {
  final String id;
  final String nombre;
  final VoidCallback onTap;
  const _ParcheCard({required this.id, required this.nombre, required this.onTap});
  @override
  State<_ParcheCard> createState() => _ParcheCardState();
}

class _ParcheCardState extends State<_ParcheCard> {
  final repo = ParchesRepository();
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: repo.getTotales(widget.id),
      builder: (c, snap) {
        final total = snap.data?['total_cop'] ?? 0;
        final miembros = snap.data?['total_miembros'] ?? 0;
        return Card(
          child: ListTile(
            title: Text(widget.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Total: \$$total COP \u2022 $miembros personas'),
            trailing: const Icon(Icons.chevron_right),
            onTap: widget.onTap,
          ),
        );
      },
    );
  }
}
