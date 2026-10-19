import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class CurrencyService {
  static const List<Map<String, String>> monedasSoportadas = [
    {'code': 'COP', 'flag': '🇨🇴', 'name': 'Peso Colombiano'},
    {'code': 'USD', 'flag': '🇺🇸', 'name': 'Dólar'},
    {'code': 'THB', 'flag': '🇹🇭', 'name': 'Baht Tailandés'},
    {'code': 'VND', 'flag': '🇻🇳', 'name': 'Dong Vietnamita'},
  ];

  static List<Map<String, String>> get supportedCurrencies => monedasSoportadas;

  final Map<String, double> _cache = {'COP': 1.0};
  final Map<String, DateTime> _cacheTime = {};

  Future<double> getRateToCop(String currency) async {
    final code = currency.toUpperCase();
    if (code == 'COP') return 1.0;
    if (_cache.containsKey(code) && _cacheTime[code] != null && DateTime.now().difference(_cacheTime[code]!).inMinutes < 60) {
      return _cache[code]!;
    }
    return await refreshRate(code);
  }

  Future<double> getRate(String currency) => getRateToCop(currency);

  Future<double> refreshRate(String currency) async {
    final code = currency.toUpperCase();
    if (code == 'COP') return 1.0;
    try {
      if (kDebugMode) debugPrint('Fetching rate for $code');
      final res = await http.get(Uri.parse('https://open.er-api.com/v6/latest/$code')).timeout(const Duration(seconds: 8));
      if (kDebugMode) debugPrint('Rate response ${res.statusCode} for $code');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final rates = data['rates'] as Map<String, dynamic>?;
        final copRate = rates?['COP'] as num?;
        if (copRate != null) {
          final rate = copRate.toDouble();
          if (kDebugMode) debugPrint('Rate $code -> COP: $rate');
          _cache[code] = rate;
          _cacheTime[code] = DateTime.now();
          return rate;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching rate for $code: $e');
    }
    const fallback = {'USD': 4100.0, 'THB': 115.0, 'VND': 0.16};
    final fb = fallback[code] ?? 1.0;
    if (kDebugMode) debugPrint('Using fallback rate for $code: $fb');
    return fb;
  }
}
