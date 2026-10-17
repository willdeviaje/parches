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

  static List<Deuda> calcularBalance({
    required List<String> miembros,
    required List<Map<String, dynamic>> gastos,
  }) {
    if (miembros.isEmpty) return [];
    final total = gastos.fold<int>(0, (s, g) => s + (g['monto_cop'] as int));
    if (total == 0) return [];
    final porPersona = total / miembros.length;

    final pagadoPor = <String, int>{for (var m in miembros) m: 0};
    for (var g in gastos) {
      final qp = g['quien_pago'] as String;
      if (pagadoPor.containsKey(qp)) {
        pagadoPor[qp] = pagadoPor[qp]! + (g['monto_cop'] as int);
      }
    }

    final balances = <String, double>{};
    for (var m in miembros) {
      balances[m] = (pagadoPor[m] ?? 0) - porPersona;
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
