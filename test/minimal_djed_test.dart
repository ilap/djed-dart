import 'package:test/test.dart';

import 'package:djed/djed.dart';

class MinimalDjedStablecoinTest {
  static double bankFee = 0.01;
  static double minReserveRatio = 1.5;
  static double maxReserveRatio = 4.0;
  static double reservecoinDefaultPrice = 0.5;

  static Djed createStablecoinContract(
      double initReserves, double initStablecoins, double initReservecoins,
      {double? fee, double? defaultPrice}) {
    final oracle = MapOracle();

    oracle.updateConversionRate(PegCurrency, BaseCoin, 0.2);

    return MinimalDjed(
        oracle,
        fee ?? bankFee,
        minReserveRatio,
        maxReserveRatio,
        defaultPrice ?? reservecoinDefaultPrice,
        initReserves,
        initStablecoins,
        initReservecoins);
  }
}

void main() {
  group('Minimal Djed Test', () {
    test('Immutability', () {
      final contract =
          MinimalDjedStablecoinTest.createStablecoinContract(5.0, 10.0, 1.0);
      final amountSC = 5.0;
      final amountBaseToPay =
          amountSC * contract.oracle.conversionRate(PegCurrency, BaseCoin);
      final feeToPay = amountBaseToPay * contract.bankFee;
      final totalToPay = amountBaseToPay + feeToPay;

      final a = contract.buyStablecoins(amountSC);
      assert(a == totalToPay);
      assert(contract.stablecoins == contract.initStablecoins + amountSC);
      assert(contract.reserves == contract.initReserves + totalToPay);
      assert(contract.reservecoins == contract.initReservecoins);

      // test buying when the reserve below the minimal reserve ratio
      final contract2 =
          MinimalDjedStablecoinTest.createStablecoinContract(1.0, 4.0, 1.0);
      assert(contract2.buyStablecoins(1) != 0);

      // test buying when the reserve below the liabilities
      final contract3 =
          MinimalDjedStablecoinTest.createStablecoinContract(1.0, 6.0, 1.0);
      assert(contract3.buyStablecoins(1) != 0);
    });
  });
}
