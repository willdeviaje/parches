import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/parches_repository.dart';
import 'detalle_parche_page.dart';

class HomeParchesPage extends StatefulWidget {
  const HomeParchesPage({super.key});

  @override
  State<HomeParchesPage> createState() => _HomeParchesPageState();
}

class _HomeParchesPageState extends State<HomeParchesPage> {
  late final ParchesRepository repo;
  List<Map<String, dynamic>> parches = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    repo = ParchesRepository(Supabase.instance.client);
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => loading = true);
    final data = await repo.getParches();
    if (mounted) {
      setState(() {
        parches = data;
        loading = false;
      });
    }
  }

  Future<void> _crearParche() async {
    final ctrl = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Nuevo parche'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Ej: Viaje a Cartagena')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('Crear')),
        ],
      ),
    );
    if (nombre == null || nombre.isEmpty) return;
    await repo.createParche(nombre);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parches')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: parches.isEmpty
                  ? ListView(children: const [SizedBox(height: 100), Center(child: Text('No hay parches\nDesliza para recargar'))])
                  : ListView.builder(
                      itemCount: parches.length,
                      itemBuilder: (c, i) {
                        final p = parches[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                            title: Text(p['nombre']),
                            subtitle: Text('Creado ${p['created_at'].toString().substring(0, 10)}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => DetalleParchePage(parche: p)),
                            ).then((_) => _refresh()),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crearParche,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo parche'),
      ),
    );
  }
}
