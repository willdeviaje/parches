class Deuda {
  final String deudor;
  final String acreedor;
  final int montoCop;
  Deuda({required this.deudor, required this.acreedor, required this.montoCop});
  @override
  String toString() => '$deudor debe a $acreedor \$$montoCop';
}

class BalanceCalculator {
  static const tasas = {'COP': 1.0, 'THB': 115.0, 'VND': 0.16, 'USD': 4100.0};

  static int toCop(num monto, String moneda) {
    return (monto * (tasas[moneda] ?? 1.0)).round();
  }

  // Fase 3 - Soporta división desigual por montos
  // Si gasto tiene division_tipo='montos' y division_data=[{nombre,monto_cop}], usa eso
  // Si no, divide igual entre miembros (MVP1)
  static List<Deuda> calcularBalance({
    required List<String> miembros,
    required List<Map<String, dynamic>> gastos,
  }) {
    if (miembros.isEmpty) return [];
    if (gastos.isEmpty) return [];

    final pagadoPor = <String, int>{for (var m in miembros) m: 0};
    final debePagar = <String, int>{for (var m in miembros) m: 0};

    for (var g in gastos) {
      final qp = g['quien_pago'] as String;
      final montoCop = (g['monto_cop'] as int?) ?? 0;
      if (pagadoPor.containsKey(qp)) {
        pagadoPor[qp] = pagadoPor[qp]! + montoCop;
      }

      final divisionTipo = (g['division_tipo'] as String?) ?? 'igual';
      final divisionData = g['division_data'];

      if (divisionTipo == 'montos' && divisionData is List && divisionData.isNotEmpty) {
        // División desigual: cada entrada tiene {nombre, monto_cop}
        for (var entry in divisionData) {
          final nombre = entry['nombre'] as String?;
          final monto = entry['monto_cop'] as int? ?? entry['monto'] as int? ?? 0;
          if (nombre != null && debePagar.containsKey(nombre)) {
            debePagar[nombre] = debePagar[nombre]! + monto;
          }
        }
      } else {
        // División igual MVP1
        final porPersona = montoCop / miembros.length;
        for (var m in miembros) {
          debePagar[m] = (debePagar[m]! + porPersona).round();
        }
      }
    }

    final balances = <String, double>{};
    for (var m in miembros) {
      balances[m] = (pagadoPor[m] ?? 0).toDouble() - (debePagar[m] ?? 0).toDouble();
    }

    final deudores = balances.entries.where((e) => e.value < -0.5).toList()..sort((a,b) => a.value.compareTo(b.value));
    final acreedores = balances.entries.where((e) => e.value > 0.5).toList()..sort((a,b) => b.value.compareTo(a.value));

    final deudas = <Deuda>[];
    int i = 0, j = 0;
    while (i < deudores.length && j < acreedores.length) {
      final deudor = deudores[i];
      final acreedor = acreedores[j];
      final montoDeuda = (-deudor.value).round();
      final montoCredito = acreedor.value.round();
      final pago = montoDeuda < montoCredito ? montoDeuda : montoCredito;
      if (pago > 0) {
        deudas.add(Deuda(deudor: deudor.key, acreedor: acreedor.key, montoCop: pago));
        deudores[i] = MapEntry(deudor.key, deudor.value + pago);
        acreedores[j] = MapEntry(acreedor.key, acreedor.value - pago);
      }
      if (deudores[i].value.abs() < 1) i++;
      if (acreedores[j].value.abs() < 1) j++;
    }
    return deudas;
  }
}
