// ignore_for_file: non_constant_identifier_names

enum Currency { pegCurrency, baseCoin, stableCoin, reserveCoin }

final PegCurrency = Currency.pegCurrency;
final BaseCoin = Currency.baseCoin;
final StableCoin = Currency.stableCoin;
final ReserveCoin = Currency.reserveCoin;

abstract class Oracle {
  double conversionRate(Currency from, Currency to);
  void updateConversionRate(Currency from, Currency to, double rate);
}

class SimpleMapOracle extends Oracle {
  final m = <String, double?>{};

  @override
  double conversionRate(Currency from, Currency to) =>
      m[from.name + to.name] ?? 0;

  @override
  void updateConversionRate(Currency from, Currency to, double rate) {
    m[from.name + to.name] = rate;
  }
}
