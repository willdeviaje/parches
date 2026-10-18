import 'dart:convert';
import 'package:http/http.dart' as http;

class CurrencyService {
  // API gratuita, sin key y con CORS permitido para web
  // https://www.exchangerate-api.com - 1500 req/mes gratis, endpoint open
  // Backup: open.er-api.com

  static const monedasSoportadas = [
    {'code': 'COP', 'name': 'Peso Colombiano', 'symbol': '\$', 'flag': '🇨🇴'},
    {'code': 'USD', 'name': 'Dólar', 'symbol': 'US\$', 'flag': '🇺🇸'},
    {'code': 'THB', 'name': 'Baht Tailandés', 'symbol': '฿', 'flag': '🇹🇭'},
    {'code': 'VND', 'name': 'Dong Vietnamita', 'symbol': '₫', 'flag': '🇻🇳'},
    {'code': 'EUR', 'name': 'Euro', 'symbol': '€', 'flag': '🇪🇺'},
  ];

  // Cache para no pegar a la API
  final Map<String, double> _cache = {};
  DateTime? _lastFetch;
  static const _cacheMinutes = 30;

  // Fallback por si no hay internet
  static const _fallbackRates = {
    'USD': 4150.0,
    'THB': 115.0,
    'VND': 0.17,
    'EUR': 4500.0,
    'COP': 1.0,
  };

  bool get _isCacheValid {
    if (_lastFetch == null) return false;
    return DateTime.now().difference(_lastFetch!).inMinutes < _cacheMinutes;
  }

  Future<double> getRateToCop(String fromCurrency) async {
    if (fromCurrency == 'COP') return 1.0;

    // Usar cache si es válido
    if (_isCacheValid && _cache.containsKey(fromCurrency)) {
      print('💰 Tasa desde cache: $fromCurrency -> ${_cache[fromCurrency]} COP');
      return _cache[fromCurrency]!;
    }

    // Intento 1: open.er-api.com (la más estable para web)
    try {
      print('🌐 Buscando tasa $fromCurrency -> COP en open.er-api.com');
      final url = Uri.parse('https://open.er-api.com/v6/latest/$fromCurrency');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['result'] == 'success' && data['rates'] != null && data['rates']['COP'] != null) {
          final rate = (data['rates']['COP'] as num).toDouble();
          _cache[fromCurrency] = rate;
          _lastFetch = DateTime.now();
          print('✅ Tasa encontrada: 1 $fromCurrency = $rate COP');
          return rate;
        }
      }
    } catch (e) {
      print('❌ Error open.er-api: $e');
    }

    // Intento 2: exchangerate-api.com v4 (también con CORS)
    try {
      print('🌐 Intento 2: exchangerate-api.com');
      final url2 = Uri.parse('https://api.exchangerate-api.com/v4/latest/$fromCurrency');
      final res2 = await http.get(url2);
      if (res2.statusCode == 200) {
        final data2 = jsonDecode(res2.body);
        if (data2['rates'] != null && data2['rates']['COP'] != null) {
          final rate = (data2['rates']['COP'] as num).toDouble();
          _cache[fromCurrency] = rate;
          _lastFetch = DateTime.now();
          print('✅ Tasa encontrada (intento2): 1 $fromCurrency = $rate COP');
          return rate;
        }
      }
    } catch (e) {
      print('❌ Error intento 2: $e');
    }

    // Fallback
    print('⚠️ Usando fallback para $fromCurrency');
    final fallback = _fallbackRates[fromCurrency] ?? 1.0;
    _cache[fromCurrency] = fallback;
    return fallback;
  }

  // Fuerza refresh ignorando cache
  Future<double> refreshRate(String fromCurrency) async {
    _cache.remove(fromCurrency);
    _lastFetch = null;
    return getRateToCop(fromCurrency);
  }

  double convertirACop(double montoOriginal, double tasa) {
    return montoOriginal * tasa;
  }
}
