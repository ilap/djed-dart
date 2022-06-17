// ignore_for_file: prefer_final_fields

library djed;

import 'dart:math';
import 'oracle.dart';

import 'package:tuple/tuple.dart';

part 'minimal_djed.dart';
part 'extended_djed.dart';

abstract class Djed {
  /// Protected fields. Only the inherited classes in the same library can access to them.
  Djed(this.oracle, this.bankFee, this.reservecoinDefaultPrice,
      this.initReserves, this.initStablecoins, this.initReservecoins) {
    _reserves = initReserves;
    _stablecoins = initStablecoins;
    _reservecoins = initReservecoins;
  }

  final Oracle oracle;
  final double bankFee;
  final double reservecoinDefaultPrice;

  late double _reserves;
  late double _stablecoins;
  late double _reservecoins;

  final double initReserves;
  final double initStablecoins;
  final double initReservecoins;

  double get reserves => _reserves; // R
  double get stablecoins => _stablecoins; // Nsc
  double get reservecoins => _reservecoins; // Nrc

  double get targetPrice =>
      oracle.conversionRate(Currency.pegCurrency, Currency.baseCoin);

  double targetLiabilities({double? nsc}) => (nsc ?? 0.0) * targetPrice;
  double normLiabilities({double? R, double? nsc});

  double reservecoinNominalPrice({double? R, double? nsc, double? nrc});
  double stablecoinNominalPrice({double? R, double? nsc});

  double reservesRatio({double? R, double? nsc}) {
    return (R ?? reserves) / targetLiabilities(nsc: nsc);
  }

  double equity({double? R, double? nsc}) {
    return (R ?? reserves) - normLiabilities(R: R, nsc: nsc);
  }

  double calculateBasecoinsForMintedStablecoins(double amountSC);
  double calculateBasecoinsForMintedReservecoins(double amountRC);

  double calculateBasecoinsForBurnedStablecoins(double amountSC);
  double calculateBasecoinsForBurnedReservecoins(double amountRC);

  double buyStablecoins(double amountSC);
  double sellStablecoins(double amountSC);
  double buyReservecoins(double amountRC);
  double sellReservecoins(double amountRC);

  static const errorMessage = '';

  void require(bool predicate, {String msg = errorMessage}) {
    if (!predicate) throw Exception(msg);
  }
}
