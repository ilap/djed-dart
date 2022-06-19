// ignore_for_file: constant_identifier_names, non_constant_identifier_names

import 'package:test/test.dart';

import 'package:djed/stablecoin.dart';

class ExtendedDjedTest {
  static const double bankFee = 0.03;
  static const double pegReservesRatio = 1.5;
  static const double optimalReserveRatio = 4.0;
  static const double reservecoinDefaultPrice = 0.5;

  static const double k_rm_def = 1.1; // fee deviation coeff for RC minting;
  static const double k_rr_def = 1.1; // fee deviation coeff for RC redeeming;
  static const double k_sm_def = 1.1; // fee deviation coeff for SC minting;
  static const double k_sr_def = 1.1; // fee deviation coeff for SC redeeming;

  static ExtendedDjed createStablecoinContract(double initReserves,
      double initStablecoins, double initReservecoins, double exchangeRate,
      {double fee = bankFee,
      double k_rm = k_rm_def,
      double k_rr = k_rr_def,
      double k_sm = k_sm_def,
      double k_sr = k_sr_def,
      double defaultPrice = reservecoinDefaultPrice,
      double optReservesRatio = optimalReserveRatio}) {
    final oracle = SimpleMapOracle();

    oracle.updateConversionRate(PegCurrency, BaseCoin, exchangeRate);

    return ExtendedDjed(
        oracle,
        fee,
        defaultPrice,
        pegReservesRatio,
        optReservesRatio,
        k_rm,
        k_rr,
        k_sm,
        k_sr,
        initReserves,
        initStablecoins,
        initReservecoins);
  }

  static void checkPostState(
      Djed contract, double deltaReserve, double deltaSC, double deltaRC) {
    assert(contract.stablecoins == contract.initStablecoins + deltaSC);
    assert(contract.reserves == contract.initReserves + deltaReserve);
    assert(contract.reservecoins == contract.initReservecoins + deltaRC);
  }
}

void main() {
  group('Minimal Djed Test', () {
    test('buy stablecoins when init/final reserve ratio above optimum', () {
      final contract = ExtendedDjedTest.createStablecoinContract(
          60000.0, 20000.0, 5000.0, 1.0,
          optReservesRatio: 2.0);
      assert(contract.reservesRatio() > contract.optimalReservesRatio);
      final amountSC = 100.00;

      final expectedAmountBaseIter = contract
          .calculateBasecoinsForMintedStablecoinsIter(amountSC, accuracy: 1000);
      //
      final expectedAmountBase =
          contract.calculateBasecoinsForMintedStablecoins(amountSC);
      final referenceAmountBase = amountSC *
          contract.oracle.conversionRate(PegCurrency, BaseCoin) *
          (1 + contract.bankFee);

      assert(expectedAmountBase.toStringAsFixed(5) ==
          expectedAmountBaseIter.toStringAsFixed(5));
      assert(expectedAmountBase == referenceAmountBase);

      final amountBase = contract.buyStablecoins(amountSC.toDouble());
      assert(amountBase == referenceAmountBase);
      assert(contract.reservesRatio() > contract.optimalReservesRatio);

      expect(
          () => ExtendedDjedTest.checkPostState(
              contract, amountBase, amountSC.toDouble(), 0),
          returnsNormally);
    });

    test('buy stablecoins when init/final reserve ratio below optimum', () {
      final contract = ExtendedDjedTest.createStablecoinContract(
          60000.0, 20000.0, 5000.0, 1.0,
          optReservesRatio: 4);
      assert(contract.reservesRatio() < contract.optimalReservesRatio);
      assert(contract.reservesRatio() > contract.pegReservesRatio);
      final amountSC = 100.00;

      final expectedAmountBaseIter = contract
          .calculateBasecoinsForMintedStablecoinsIter(amountSC, accuracy: 1000);
      final expectedAmountBase =
          contract.calculateBasecoinsForMintedStablecoins(amountSC);
      assert(expectedAmountBase.toStringAsFixed(5) ==
          expectedAmountBaseIter.toStringAsFixed(5));

      final amountBase = contract.buyStablecoins(amountSC);
      assert(amountBase == expectedAmountBase);
      assert(contract.reservesRatio() < contract.optimalReservesRatio);
      assert(contract.reservesRatio() > contract.pegReservesRatio);

      expect(
          () => ExtendedDjedTest.checkPostState(
              contract, amountBase, amountSC.toDouble(), 0),
          returnsNormally);
    });

    test(
        'buy stablecoins when init reserve ratio above optimum but final ratio is below optimum',
        () {
      final contract = ExtendedDjedTest.createStablecoinContract(
          80200.0, 20000.0, 5000.0, 1.0,
          optReservesRatio: 4);
      assert(contract.reservesRatio() > contract.optimalReservesRatio);
      final amountSC = 300.0;

      final expectedAmountBaseIter = contract
          .calculateBasecoinsForMintedStablecoinsIter(amountSC, accuracy: 1000);
      final expectedAmountBase =
          contract.calculateBasecoinsForMintedStablecoins(amountSC);
      // NOTE: IEEE-754 floating point peculiarity
      // Different precisions in different settings
      assert(expectedAmountBase.toStringAsFixed(3) ==
          expectedAmountBaseIter.toStringAsFixed(3));

      final amountBase = contract.buyStablecoins(amountSC);
      assert(amountBase == expectedAmountBase);
      assert(contract.reservesRatio() < contract.optimalReservesRatio);
      expect(
          () => ExtendedDjedTest.checkPostState(
              contract, amountBase, amountSC.toDouble(), 0),
          returnsNormally);
    });

    test('buy stablecoins when reserve ratio below peg', () {
      final contract = ExtendedDjedTest.createStablecoinContract(
          29000.0, 20000.0, 5000.0, 1.0,
          optReservesRatio: 4);
      assert(contract.reservesRatio() < contract.pegReservesRatio);
      expect(() => contract.calculateBasecoinsForMintedStablecoins(1),
          throwsException);

      expect(() => contract.buyStablecoins(1), throwsException);

      // test when initial ratio above peg but final becomes below peg;
      final contract2 = ExtendedDjedTest.createStablecoinContract(
          30100.0, 20000.0, 5000.0, 1.0,
          optReservesRatio: 2);
      assert(contract2.reservesRatio() > contract2.pegReservesRatio);
      expect(() => contract2.calculateBasecoinsForMintedStablecoins(2000),
          throwsException);
      //assert(contract2.buyStablecoins(2000, throwsException);
    });

    test('sell stablecoins when init/final reserve ratio above optimum', () {
      final contract = ExtendedDjedTest.createStablecoinContract(
          41000.0, 20000.0, 5000.0, 1.0,
          optReservesRatio: 2);
      assert(contract.reservesRatio() > contract.optimalReservesRatio);
      final amountSC = 90.0;

      final expectedAmountBaseIter = contract
          .calculateBasecoinsForBurnedStablecoinsIter(amountSC, accuracy: 1000);
      final expectedAmountBase =
          contract.calculateBasecoinsForBurnedStablecoins(amountSC);
      assert(expectedAmountBase.toStringAsFixed(5) ==
          expectedAmountBaseIter.toStringAsFixed(5));

      //final (amountBase, amountRC)
      final tuple = contract.sellStablecoinsWithSwap(amountSC);

      assert(tuple.item1 == expectedAmountBase);
      assert(contract.reservesRatio() > contract.optimalReservesRatio);
      //jassert(checkPostState(contract, -amountBase, -amountSC, 0), returnsNormally);
      expect(
          () => ExtendedDjedTest.checkPostState(
              contract, -tuple.item1, -amountSC, 0),
          returnsNormally);
    });

    test(
        'sell stablecoins when init/final reserve ratio below optimum and above peg',
        () {
      final contract = ExtendedDjedTest.createStablecoinContract(
          35000.0, 20000.0, 5000.0, 1.1,
          optReservesRatio: 2);
      assert(contract.reservesRatio() < contract.optimalReservesRatio);
      assert(contract.reservesRatio() > contract.pegReservesRatio);
      final amountSC = 100.0;

      final expectedAmountBaseIter = contract
          .calculateBasecoinsForBurnedStablecoinsIter(amountSC, accuracy: 1000);
      final expectedAmountBase =
          contract.calculateBasecoinsForBurnedStablecoins(amountSC);
      assert(expectedAmountBase.toStringAsFixed(5) ==
          expectedAmountBaseIter.toStringAsFixed(5));

      //final (amountBase, amountRC)
      final tuple = contract.sellStablecoinsWithSwap(amountSC);
      assert(tuple.item1 == expectedAmountBase);
      assert(contract.reservesRatio() < contract.optimalReservesRatio);
      assert(contract.reservesRatio() > contract.pegReservesRatio);
      //assert(checkPostState(contract, -amountBase, -amountSC, 0), returnsNormally);
      expect(
          () => ExtendedDjedTest.checkPostState(
              contract, -tuple.item1, -amountSC, 0),
          returnsNormally);
    });

    test('sell stablecoins when init/final reserve ratio below peg', () {
      final contract = ExtendedDjedTest.createStablecoinContract(
          29000.0, 20000.0, 5000.0, 1.1,
          optReservesRatio: 2);
      assert(contract.reservesRatio() < contract.pegReservesRatio);
      final amountSC = 100.0;

      final expectedAmountBaseIter = contract
          .calculateBasecoinsForBurnedStablecoinsIter(amountSC, accuracy: 1000);
      final expectedAmountBase =
          contract.calculateBasecoinsForBurnedStablecoins(amountSC);
      assert(expectedAmountBase.toStringAsFixed(5) ==
          expectedAmountBaseIter.toStringAsFixed(5));

      //final (amountBase, amountRC)
      final tuple = contract.sellStablecoinsWithSwap(amountSC);
      assert(tuple.item1 == expectedAmountBase);
      //assert(checkPostState(contract, -amountBase, -amountSC, amountRC), returnsNormally);

      expect(
          () => ExtendedDjedTest.checkPostState(
              contract, -tuple.item1, -amountSC, tuple.item2),
          returnsNormally);
      assert(contract.reservesRatio() < contract.pegReservesRatio);
    });

    test(
        'sell stablecoins when init reserve ratio below optimum and above peg, final ratio above optimum',
        () {
      final contract = ExtendedDjedTest.createStablecoinContract(
          39900.0, 20000.0, 5000.0, 1.0,
          optReservesRatio: 2);
      assert(contract.reservesRatio() < contract.optimalReservesRatio);
      assert(contract.reservesRatio() > contract.pegReservesRatio);
      final amountSC = 500.0;

      final expectedAmountBaseIter = contract
          .calculateBasecoinsForBurnedStablecoinsIter(amountSC, accuracy: 1000);
      final expectedAmountBase =
          contract.calculateBasecoinsForBurnedStablecoins(amountSC);
      assert(expectedAmountBase.toStringAsFixed(4) ==
          expectedAmountBaseIter.toStringAsFixed(4));

      final expectedAmountRcIter =
          contract.calculateReservecoinsForBurnedStablecoinsIter(amountSC,
              accuracy: 100);
      final expectedAmountRc =
          contract.calculateReservecoinsForBurnedStablecoins(amountSC);
      assert(expectedAmountRc.toStringAsFixed(5) ==
          expectedAmountRcIter.toStringAsFixed(5));

      //final (amountBase, amountRC)
      final tuple = contract.sellStablecoinsWithSwap(amountSC);
      assert(tuple.item1 == expectedAmountBase);
      assert(tuple.item2 == expectedAmountRc);
      expect(
          () => ExtendedDjedTest.checkPostState(
              contract, -tuple.item1, -amountSC, 0),
          returnsNormally);
      assert(contract.reservesRatio() > contract.optimalReservesRatio);
    });

    test(
        'sell stablecoins when init reserve ratio below peg, final ratio above optimum',
        () {
      final contract = ExtendedDjedTest.createStablecoinContract(
          29500.0, 20000.0, 5000.0, 1.0,
          optReservesRatio: 1.6);
      assert(contract.reservesRatio() < contract.pegReservesRatio);
      final amountSC = 5000.0;

      final expectedAmountBaseIter = contract
          .calculateBasecoinsForBurnedStablecoinsIter(amountSC, accuracy: 100);
      final expectedAmountBase =
          contract.calculateBasecoinsForBurnedStablecoins(amountSC);
      assert(expectedAmountBase.toStringAsFixed(3) ==
          expectedAmountBaseIter.toStringAsFixed(3));

      final expectedAmountRcIter =
          contract.calculateReservecoinsForBurnedStablecoinsIter(amountSC,
              accuracy: 100);
      final expectedAmountRc =
          contract.calculateReservecoinsForBurnedStablecoins(amountSC);
      assert(expectedAmountRc.toStringAsFixed(3) ==
          expectedAmountRcIter.toStringAsFixed(3));

      //final (amountBase, amountRC)
      final tuple = contract.sellStablecoinsWithSwap(amountSC);
      assert(tuple.item1 == expectedAmountBase);
      assert(tuple.item2 == expectedAmountRc);
      expect(
          () => ExtendedDjedTest.checkPostState(
              contract, -tuple.item1, -amountSC, tuple.item2),
          returnsNormally);
      assert(contract.reservesRatio() > contract.optimalReservesRatio);
    });

    test(
        'sell stablecoins when init reserve ratio below peg, final ratio above peg below optimum',
        () {
      final contract = ExtendedDjedTest.createStablecoinContract(
          29500.0, 20000.0, 5000.0, 1.0,
          optReservesRatio: 2);
      assert(contract.reservesRatio() < contract.pegReservesRatio);
      final amountSC = 5000.0;

      final expectedAmountBaseIter = contract
          .calculateBasecoinsForBurnedStablecoinsIter(amountSC, accuracy: 100);
      final expectedAmountBase =
          contract.calculateBasecoinsForBurnedStablecoins(amountSC);
      assert(expectedAmountBase.toStringAsFixed(3) ==
          expectedAmountBaseIter.toStringAsFixed(3));

      final expectedAmountRcIter =
          contract.calculateReservecoinsForBurnedStablecoinsIter(amountSC,
              accuracy: 100);
      final expectedAmountRc =
          contract.calculateReservecoinsForBurnedStablecoins(amountSC);
      assert(expectedAmountRc.toStringAsFixed(3) ==
          expectedAmountRcIter.toStringAsFixed(3));

      //final (amountBase, amountRC)
      final tuple = contract.sellStablecoinsWithSwap(amountSC);
      assert(tuple.item1 == expectedAmountBase);
      assert(tuple.item2 == expectedAmountRc);
      expect(
          () => ExtendedDjedTest.checkPostState(
              contract, -tuple.item1, -amountSC, tuple.item2),
          returnsNormally);
      assert(contract.reservesRatio() > contract.pegReservesRatio);
      assert(contract.reservesRatio() < contract.optimalReservesRatio);
    });

    test('sell stablecoins when init reserve ratio below 1', () {
      final contract = ExtendedDjedTest.createStablecoinContract(
          19500.0, 20000.0, 5000.0, 1.1,
          optReservesRatio: 2);
      assert(contract.reservesRatio() < 1);
      final amountSC = 1800.0;

      final expectedAmountBaseIter = contract
          .calculateBasecoinsForBurnedStablecoinsIter(amountSC, accuracy: 100);
      final expectedAmountBase =
          contract.calculateBasecoinsForBurnedStablecoins(amountSC);
      assert(expectedAmountBase.toStringAsFixed(3) ==
          expectedAmountBaseIter.toStringAsFixed(3));

      final expectedAmountRcIter =
          contract.calculateReservecoinsForBurnedStablecoinsIter(amountSC,
              accuracy: 100);
      final expectedAmountRc =
          contract.calculateReservecoinsForBurnedStablecoins(amountSC);
      assert(expectedAmountRc.toStringAsFixed(2) ==
          expectedAmountRcIter.toStringAsFixed(2));

      //final (amountBase, amountRC)
      final tuple = contract.sellStablecoinsWithSwap(amountSC);
      assert(tuple.item1 == expectedAmountBase);
      assert(tuple.item2 == expectedAmountRc);
    });

    test('sell stablecoins with swap', () {
      final contract = ExtendedDjedTest.createStablecoinContract(
          19500.0, 20000.0, 5000.0, 1.1,
          optReservesRatio: 2);
      assert(contract.reservesRatio() < contract.pegReservesRatio);
      final amountSC = 1000.0;

      final expectedAmountBaseIter = contract
          .calculateBasecoinsForBurnedStablecoinsIter(amountSC, accuracy: 100);
      final expectedAmountBase =
          contract.calculateBasecoinsForBurnedStablecoins(amountSC);
      assert(expectedAmountBase.toStringAsFixed(3) ==
          expectedAmountBaseIter.toStringAsFixed(3));

      final expectedAmountRcIter =
          contract.calculateReservecoinsForBurnedStablecoinsIter(amountSC,
              accuracy: 100);
      final expectedAmountRc =
          contract.calculateReservecoinsForBurnedStablecoins(amountSC);
      assert(expectedAmountRc.toStringAsFixed(3) ==
          expectedAmountRcIter.toStringAsFixed(3));

      //final (amountBase, amountRC)
      final tuple = contract.sellStablecoinsWithSwap(amountSC);
      assert(tuple.item1 == expectedAmountBase);
      assert(tuple.item2 == expectedAmountRc);
    });

    test('buy reservecoins', () {
      final contract = ExtendedDjedTest.createStablecoinContract(
          20000.0, 20000.0, 5000.0, 1.0);
      final amountRC = 100.0;

      final expectedAmountBaseIter =
          contract.calculateBasecoinsForMintedReservecoinsIter(amountRC,
              accuracy: 10000);
      final expectedAmountBase =
          contract.calculateBasecoinsForMintedReservecoins(amountRC);
      assert(expectedAmountBase.toStringAsFixed(5) ==
          expectedAmountBaseIter.toStringAsFixed(5));

      final amountBase = contract.buyReservecoins(amountRC);
      assert(amountBase == expectedAmountBase);
      expect(
          () => ExtendedDjedTest.checkPostState(
              contract, amountBase, 0, amountRC),
          returnsNormally);
    });

    test(
        'buy reservecoins (1-st variant):'
        ' initial and new reserve ratio are below peg', () {
      final contract = ExtendedDjedTest.createStablecoinContract(
          20000.0, 20000.0, 5000.0, 1.0);
      assert(contract.reservesRatio() < contract.pegReservesRatio);
      final amountRC = 100.0;
      final expectedAmountBaseIter =
          contract.calculateBasecoinsForMintedReservecoinsIter(amountRC,
              accuracy: 1000);
      final expectedAmountBase =
          contract.calculateBasecoinsForMintedReservecoins(amountRC);
      assert(expectedAmountBase.toStringAsFixed(4) ==
          expectedAmountBaseIter.toStringAsFixed(4));
      final amountBase = contract.buyReservecoins(amountRC);
      assert(amountBase == expectedAmountBase);
      assert(contract.reservesRatio() < contract.pegReservesRatio);
    });

    test(
        'buy reservecoins (2-nd variant):'
        'initial reserve ratio is below peg, new ratio is above peg but below optimum',
        () {
      final contract2 = ExtendedDjedTest.createStablecoinContract(
          29000.0, 20000.0, 5000.0, 1.0);
      assert(contract2.reservesRatio() < contract2.pegReservesRatio);
      final amountRC2 = 2000.0;
      final expectedAmountBaseIter2 =
          contract2.calculateBasecoinsForMintedReservecoinsIter(amountRC2,
              accuracy: 1000);
      final expectedAmountBase2 =
          contract2.calculateBasecoinsForMintedReservecoins(amountRC2);
      assert(expectedAmountBase2.toStringAsFixed(3) ==
          expectedAmountBaseIter2.toStringAsFixed(3));
      final amountBase2 = contract2.buyReservecoins(amountRC2);
      assert(amountBase2 == expectedAmountBase2);
      assert(contract2.reservesRatio() > contract2.pegReservesRatio &&
          contract2.reservesRatio() < contract2.optimalReservesRatio);
    });

    test(
        'buy reservecoins (3-rd variant):'
        ' initial reserve ratio is below peg, new ratio is above optimum', () {
      final optimalReserveRatio = 2.0;
      final contract3 = ExtendedDjedTest.createStablecoinContract(
          29000.0, 20000.0, 5000.0, 1.0,
          optReservesRatio: optimalReserveRatio);
      assert(contract3.reservesRatio() < contract3.pegReservesRatio);
      final amountRC3 = 7000.0;
      final expectedAmountBaseIter3 =
          contract3.calculateBasecoinsForMintedReservecoinsIter(amountRC3,
              accuracy: 1000);
      final expectedAmountBase3 =
          contract3.calculateBasecoinsForMintedReservecoins(amountRC3);
      assert(expectedAmountBase3.toStringAsFixed(3) ==
          expectedAmountBaseIter3.toStringAsFixed(3));
      final amountBase3 = contract3.buyReservecoins(amountRC3);
      assert(amountBase3 == expectedAmountBase3);
      assert(contract3.reservesRatio() > optimalReserveRatio);
    });

    test(
        'buy reservecoins (4-th variant):'
        ' initial and new reserve ratio are above peg but below optimum', () {
      final contract = ExtendedDjedTest.createStablecoinContract(
          35000.0, 20000.0, 5000.0, 1.0);
      assert(contract.reservesRatio() > contract.pegReservesRatio &&
          contract.reservesRatio() < contract.optimalReservesRatio);
      final amountRC = 100.0;
      final expectedAmountBaseIter =
          contract.calculateBasecoinsForMintedReservecoinsIter(amountRC,
              accuracy: 1000);
      final expectedAmountBase =
          contract.calculateBasecoinsForMintedReservecoins(amountRC);
      assert(expectedAmountBase.toStringAsFixed(5) ==
          expectedAmountBaseIter.toStringAsFixed(5));
      final amountBase = contract.buyReservecoins(amountRC);
      assert(amountBase == expectedAmountBase);
      assert(contract.reservesRatio() > contract.pegReservesRatio &&
          contract.reservesRatio() < contract.optimalReservesRatio);
    });

    test(
        'buy reservecoins (5-th variant):'
        ' initial reserve ratio is above peg but below optimum, new ratio is above optimum',
        () {
      final optimalReserveRatio = 2.0;
      final contract2 = ExtendedDjedTest.createStablecoinContract(
          37000.0, 20000.0, 5000.0, 1.0,
          optReservesRatio: optimalReserveRatio);
      assert(contract2.reservesRatio() > contract2.pegReservesRatio &&
          contract2.reservesRatio() < contract2.optimalReservesRatio);
      final amountRC2 = 1000.0;
      final expectedAmountBaseIter2 =
          contract2.calculateBasecoinsForMintedReservecoinsIter(amountRC2,
              accuracy: 1000);
      final expectedAmountBase2 =
          contract2.calculateBasecoinsForMintedReservecoins(amountRC2);
      assert(expectedAmountBase2.toStringAsFixed(3) ==
          expectedAmountBaseIter2.toStringAsFixed(3));
      final amountBase2 = contract2.buyReservecoins(amountRC2);
      assert(amountBase2 == expectedAmountBase2);
      assert(contract2.reservesRatio() > contract2.optimalReservesRatio);
    });

    test(
        'buy reservecoins (6-th variant): initial and new reserve ratio are above the optimum',
        () {
      final optimalReserveRatio = 2.0;
      final contract = ExtendedDjedTest.createStablecoinContract(
          45000.0, 20000.0, 5000.0, 1.0,
          optReservesRatio: optimalReserveRatio);
      assert(contract.reservesRatio() > contract.optimalReservesRatio);
      final amountRC = 500.0;
      final expectedAmountBaseIter =
          contract.calculateBasecoinsForMintedReservecoinsIter(amountRC,
              accuracy: 1000);
      final expectedAmountBase =
          contract.calculateBasecoinsForMintedReservecoins(amountRC);
      assert(expectedAmountBase.toStringAsFixed(3) ==
          expectedAmountBaseIter.toStringAsFixed(3));
      final amountBase = contract.buyReservecoins(amountRC);
      assert(amountBase == expectedAmountBase);
      assert(contract.reservesRatio() > contract.optimalReservesRatio);
    });

    test(
        'buy reservecoins when initial reserve ratio at peg/optimum boundaries',
        () {
      // Test when initial ratio at peg;
      final contract = ExtendedDjedTest.createStablecoinContract(
          30000.0, 20000.0, 5000.0, 1.0);
      assert(contract.reservesRatio() == contract.pegReservesRatio);
      final amountRC = 100.0;
      final expectedAmountBaseIter =
          contract.calculateBasecoinsForMintedReservecoinsIter(amountRC,
              accuracy: 1000);
      final expectedAmountBase =
          contract.calculateBasecoinsForMintedReservecoins(amountRC);
      assert(expectedAmountBase.toStringAsFixed(5) ==
          expectedAmountBaseIter.toStringAsFixed(5));
      final amountBase = contract.buyReservecoins(amountRC);
      assert(amountBase == expectedAmountBase);

      // Test when initial ratio at the optimum;
      final contract2 = ExtendedDjedTest.createStablecoinContract(
          80000.0, 20000.0, 5000.0, 1.0);
      assert(contract2.optimalReservesRatio == contract2.reservesRatio());
      final amountRC2 = 100.0;
      final expectedAmountBaseIter2 =
          contract2.calculateBasecoinsForMintedReservecoinsIter(amountRC2,
              accuracy: 1000);
      final expectedAmountBase2 =
          contract2.calculateBasecoinsForMintedReservecoins(amountRC2);
      assert(expectedAmountBase2.toStringAsFixed(3) ==
          expectedAmountBaseIter2.toStringAsFixed(3));
      assert(expectedAmountBase2 == contract2.buyReservecoins(amountRC2));
      assert(contract2.reservesRatio() > contract2.optimalReservesRatio);
    });

    test('buy reservecoins when bankFee or k_rm equals zero', () {
      // Test when base fee equals zero;
      final contract = ExtendedDjedTest.createStablecoinContract(
          29000.0, 20000.0, 5000.0, 1.0,
          fee: 0.0, optReservesRatio: 1.7);
      assert(contract.reservesRatio() < contract.pegReservesRatio);
      final amountRC = 3000.0;
      final expectedAmountBaseIter =
          contract.calculateBasecoinsForMintedReservecoinsIter(amountRC,
              accuracy: 1000);
      final expectedAmountBase =
          contract.calculateBasecoinsForMintedReservecoins(amountRC);
      assert(expectedAmountBase.toStringAsFixed(3) ==
          expectedAmountBaseIter.toStringAsFixed(3));
      assert(expectedAmountBase == contract.buyReservecoins(amountRC));
      assert(contract.optimalReservesRatio < contract.reservesRatio());

      // Test when k_rm equals zero;
      final contract2 = ExtendedDjedTest.createStablecoinContract(
          29000.0, 20000.0, 5000.0, 1.0,
          k_rm: 0.0, optReservesRatio: 1.7);
      assert(contract2.reservesRatio() < contract2.pegReservesRatio);
      final amountRC2 = 3000.0;
      final expectedAmountBaseIter2 =
          contract2.calculateBasecoinsForMintedReservecoinsIter(amountRC2,
              accuracy: 1000);
      final expectedAmountBase2 =
          contract2.calculateBasecoinsForMintedReservecoins(amountRC2);
      assert(expectedAmountBase2.toStringAsFixed(2) ==
          expectedAmountBaseIter2.toStringAsFixed(2));
      assert(expectedAmountBase2 == contract2.buyReservecoins(amountRC2));
      assert(contract2.reservesRatio() > contract2.optimalReservesRatio);
    });

    test('sell reservecoins', () {
      final contract = ExtendedDjedTest.createStablecoinContract(
          20000.0, 20000.0, 5000.0, 1.0);
      final amountRC = 100.0;

      final expectedAmountBaseIter =
          contract.calculateBasecoinsForBurnedReservecoinsIter(amountRC,
              accuracy: 1000);
      final expectedAmountBase =
          contract.calculateBasecoinsForBurnedReservecoins(amountRC);
      assert(expectedAmountBase.toStringAsFixed(5) ==
          expectedAmountBaseIter.toStringAsFixed(5));

      final amountBase = contract.sellReservecoins(amountRC);
      assert(amountBase == expectedAmountBase);
      expect(
          () => ExtendedDjedTest.checkPostState(
              contract, -amountBase, 0, -amountRC),
          returnsNormally);
    });

    test(
        'sell reservecoins (1-st variant): initial and new reserve ratio are below peg',
        () {
      final contract = ExtendedDjedTest.createStablecoinContract(
          20000.0, 20000.0, 5000.0, 1.0);
      assert(contract.reservesRatio() < contract.pegReservesRatio);
      final amountRC = 100.0;
      final expectedAmountBaseIter =
          contract.calculateBasecoinsForBurnedReservecoinsIter(amountRC,
              accuracy: 1000);
      final expectedAmountBase =
          contract.calculateBasecoinsForBurnedReservecoins(amountRC);
      assert(expectedAmountBase.toStringAsFixed(5) ==
          expectedAmountBaseIter.toStringAsFixed(5));
      final amountBase = contract.sellReservecoins(amountRC);
      assert(amountBase == expectedAmountBase);
      assert(contract.reservesRatio() < contract.pegReservesRatio);
    });

    test(
        'sell reservecoins (2-nd variant):'
        'initial reserve ratio is above peg but below optimum, new ratio is below peg',
        () {
      final contract2 = ExtendedDjedTest.createStablecoinContract(
          30010.0, 20000.0, 5000.0, 1.0);
      assert(contract2.reservesRatio() < contract2.optimalReservesRatio &&
          contract2.reservesRatio() > contract2.pegReservesRatio);
      final amountRC2 = 200.0;
      final expectedAmountBaseIter2 =
          contract2.calculateBasecoinsForBurnedReservecoinsIter(amountRC2,
              accuracy: 1000);
      final expectedAmountBase2 =
          contract2.calculateBasecoinsForBurnedReservecoins(amountRC2);
      assert(expectedAmountBase2.toStringAsFixed(4) ==
          expectedAmountBaseIter2.toStringAsFixed(4));
      final amountBase2 = contract2.sellReservecoins(amountRC2);
      assert(amountBase2 == expectedAmountBase2);
      assert(contract2.reservesRatio() < contract2.pegReservesRatio);
    });

    test(
        'sell reservecoins (3-rd variant):'
        ' initial reserve ratio above the optimum, new ratio is below the peg',
        () {
      final optimalReserveRatio = 1.6;
      final contract3 = ExtendedDjedTest.createStablecoinContract(
          32500.0, 20000.0, 5000.0, 1.0,
          optReservesRatio: optimalReserveRatio);
      assert(contract3.reservesRatio() > contract3.optimalReservesRatio);
      final amountRC3 = 2000.0;
      final expectedAmountBaseIter3 =
          contract3.calculateBasecoinsForBurnedReservecoinsIter(amountRC3,
              accuracy: 1000);
      final expectedAmountBase3 =
          contract3.calculateBasecoinsForBurnedReservecoins(amountRC3);
      assert(expectedAmountBase3.toStringAsFixed(3) ==
          expectedAmountBaseIter3.toStringAsFixed(3));
      final amountBase3 = contract3.sellReservecoins(amountRC3);
      assert(amountBase3 == expectedAmountBase3);
      assert(contract3.reservesRatio() < contract3.pegReservesRatio);
    });

    test(
        'sell reservecoins (4-th variant):'
        'initial and new reserve ratio are above peg but below optimum', () {
      final contract4 = ExtendedDjedTest.createStablecoinContract(
          40000.0, 20000.0, 5000.0, 1.0);
      assert(contract4.reservesRatio() < contract4.optimalReservesRatio &&
          contract4.reservesRatio() > contract4.pegReservesRatio);
      final amountRC4 = 200.0;
      final expectedAmountBaseIter4 =
          contract4.calculateBasecoinsForBurnedReservecoinsIter(amountRC4,
              accuracy: 1000);
      final expectedAmountBase4 =
          contract4.calculateBasecoinsForBurnedReservecoins(amountRC4);
      assert(expectedAmountBase4.toStringAsFixed(4) ==
          expectedAmountBaseIter4.toStringAsFixed(4));
      final amountBase4 = contract4.sellReservecoins(amountRC4);
      assert(amountBase4 == expectedAmountBase4);
      assert(contract4.reservesRatio() < contract4.optimalReservesRatio &&
          contract4.reservesRatio() > contract4.pegReservesRatio);
    });

    test(
        'sell reservecoins (5-th variant): '
        'initial reserve ratio is above the optimum'
        'new ratio is above peg but below optimal level', () {
      final optimalReserveRatio = 2.0;
      final contract5 = ExtendedDjedTest.createStablecoinContract(
          41000.0, 20000.0, 5000.0, 1.0,
          optReservesRatio: optimalReserveRatio);
      assert(contract5.reservesRatio() > contract5.optimalReservesRatio);
      final amountRC5 = 1000.0;
      final expectedAmountBaseIter5 =
          contract5.calculateBasecoinsForBurnedReservecoinsIter(amountRC5,
              accuracy: 1000);
      final expectedAmountBase5 =
          contract5.calculateBasecoinsForBurnedReservecoins(amountRC5);
      assert(expectedAmountBase5.toStringAsFixed(3) ==
          expectedAmountBaseIter5.toStringAsFixed(3));
      final amountBase5 = contract5.sellReservecoins(amountRC5);
      assert(amountBase5 == expectedAmountBase5);
      assert(contract5.reservesRatio() > contract5.pegReservesRatio &&
          contract5.reservesRatio() < contract5.optimalReservesRatio);
    });

    test(
        'sell reservecoins (6-th variant): '
        'initial and new reserve ratio are above the optimum', () {
      final optimalReserveRatio = 2.0;
      final contract6 = ExtendedDjedTest.createStablecoinContract(
          50000.0, 20000.0, 5000.0, 1.0,
          optReservesRatio: optimalReserveRatio);
      assert(contract6.reservesRatio() > contract6.optimalReservesRatio);
      final amountRC6 = 1000.0;
      final expectedAmountBaseIter6 =
          contract6.calculateBasecoinsForBurnedReservecoinsIter(amountRC6,
              accuracy: 1000);
      final expectedAmountBase6 =
          contract6.calculateBasecoinsForBurnedReservecoins(amountRC6);
      assert(expectedAmountBase6.toStringAsFixed(4) ==
          expectedAmountBaseIter6.toStringAsFixed(4));
      final amountBase6 = contract6.sellReservecoins(amountRC6);
      assert(amountBase6 == expectedAmountBase6);
      assert(contract6.reservesRatio() > contract6.optimalReservesRatio);
    });

    test('sell reservecoins when initial ratio at peg/optimum boundaries', () {
      // Test when initial ratio at the peg;
      final contract = ExtendedDjedTest.createStablecoinContract(
          30000.0, 20000.0, 5000.0, 1.0);
      assert(contract.reservesRatio() == contract.pegReservesRatio);
      final amountRC = 100.0;
      final expectedAmountBaseIter =
          contract.calculateBasecoinsForBurnedReservecoinsIter(amountRC,
              accuracy: 1000);
      final expectedAmountBase =
          contract.calculateBasecoinsForBurnedReservecoins(amountRC);
      assert(expectedAmountBase.toStringAsFixed(4) ==
          expectedAmountBaseIter.toStringAsFixed(4));
      assert(expectedAmountBase == contract.sellReservecoins(amountRC));
      assert(contract.reservesRatio() < contract.optimalReservesRatio);

      // Test when initial ratio at the optimum;
      final contract2 = ExtendedDjedTest.createStablecoinContract(
          40000.0, 20000.0, 5000.0, 1.0,
          optReservesRatio: 2);
      assert(contract2.optimalReservesRatio == contract2.reservesRatio());
      final expectedAmountBaseIter2 =
          contract2.calculateBasecoinsForBurnedReservecoinsIter(amountRC,
              accuracy: 1000);
      final expectedAmountBase2 =
          contract2.calculateBasecoinsForBurnedReservecoins(amountRC);
      assert(expectedAmountBase2.toStringAsFixed(2) ==
          expectedAmountBaseIter2.toStringAsFixed(2));
      assert(expectedAmountBase2 == contract2.sellReservecoins(amountRC));
      assert(contract2.reservesRatio() < contract2.optimalReservesRatio);
    });

    test('sell reservecoins when base fee or k_rr equals zero', () {
      // Test when base fee equals zero;
      final contract = ExtendedDjedTest.createStablecoinContract(
          34100.0, 20000.0, 5000.0, 1.0,
          fee: 0.0, optReservesRatio: 1.7);
      assert(contract.reservesRatio() > contract.optimalReservesRatio);
      final amountRC = 3000.0;
      final expectedAmountBaseIter =
          contract.calculateBasecoinsForBurnedReservecoinsIter(amountRC,
              accuracy: 1000);
      final expectedAmountBase =
          contract.calculateBasecoinsForBurnedReservecoins(amountRC);
      assert(expectedAmountBase.toStringAsFixed(2) ==
          expectedAmountBaseIter.toStringAsFixed(2));
      assert(expectedAmountBase == contract.sellReservecoins(amountRC));
      assert(contract.pegReservesRatio > contract.reservesRatio());

      // Test when k_rm equals zero;
      final contract2 = ExtendedDjedTest.createStablecoinContract(
          34100.0, 20000.0, 5000.0, 1.0,
          k_rr: 0.0, optReservesRatio: 1.7);
      assert(contract2.reservesRatio() > contract2.optimalReservesRatio);
      final expectedAmountBaseIter2 =
          contract2.calculateBasecoinsForBurnedReservecoinsIter(amountRC,
              accuracy: 1000);
      final expectedAmountBase2 =
          contract2.calculateBasecoinsForBurnedReservecoins(amountRC);
      assert(expectedAmountBase2.toStringAsFixed(2) ==
          expectedAmountBaseIter2.toStringAsFixed(2));
      assert(expectedAmountBase2 == contract2.sellReservecoins(amountRC));
      assert(contract2.reservesRatio() < contract2.pegReservesRatio);
    });
  });
}
