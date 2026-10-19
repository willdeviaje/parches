import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/group_repository.dart';
import 'group_detail_page.dart';

class HomeGroupsPage extends StatefulWidget {
  const HomeGroupsPage({super.key});

  @override
  State<HomeGroupsPage> createState() => _HomeGroupsPageState();
}

class _HomeGroupsPageState extends State<HomeGroupsPage> {
  late final GroupRepository repo;
  List<Map<String, dynamic>> groups = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    repo = GroupRepository(Supabase.instance.client);
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => loading = true);
    final data = await repo.getGroups();
    if (mounted) {
      setState(() {
        groups = data;
        loading = false;
      });
    }
  }

  Future<void> _createGroup() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
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
    if (name == null || name.isEmpty) return;
    await repo.createGroup(name);
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
              child: groups.isEmpty
                  ? ListView(children: const [SizedBox(height: 100), Center(child: Text('No hay parches\nDesliza para recargar'))])
                  : ListView.builder(
                      itemCount: groups.length,
                      itemBuilder: (c, i) {
                        final g = groups[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                            title: Text(g['nombre']),
                            subtitle: Text('Creado ${g['created_at'].toString().substring(0, 10)}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => GroupDetailPage(group: g)),
                            ).then((_) => _refresh()),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createGroup,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo parche'),
      ),
    );
  }
}
