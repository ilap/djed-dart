// ignore_for_file: non_constant_identifier_names

import 'dart:io';
import 'dart:math';

import 'package:djed/simulator.dart';
import 'package:djed/stablecoin.dart';

///
/// # HistoricalGame setup.
///
/// The assumptions are:
/// 1. that the stablecoins (SC) will have an exponential growth to some maximum market cap (maxMarketCap).
/// 2. this `maxMarketCap` depends on the optimal reserves driven by the reserve coin (RC) trades.
/// 	- Assuming it will reach some max capacity e.g., plateau.
/// 3. the growth of stable coins are not heavily impacted by base coin's (BC e.g., ADA) price fluctuation (this assumption is based on some historical data of the DAI and MakerDAO)
/// 4. the supply and demand of the reserve coins are based on the reserves ratio, this incentives are  highly dependent of the base coin's price.
/// 5. the reserve coins' `fee` should be high enough meaning have enough impact for having some incentives for buying and selling RCs and should not depend on only base coins' exchange rate.
///
/// ## Glossary:
/// - dynamic fee: a feature of Extended Djed
/// - target price: The actual price of the stablecoins based on the exchange rate of the basecoin
///   - e.g., 1 Djed always 1 USD that you can buy based on the base coin's (ADA's) actual price.
///   - e.g. While 1 Djed is always 1 USD, 1 Shen is initially 0.5 Djed i.e. `2 Shen = 1 Djed`, but RC's price can change.
/// - target liabilities: represent the full amount of debt to stablecoins holders
/// - nominal liabilities:
/// - nominal price: shows amount of basecoins worth of **one** stable- or one reservecoin.
///
void main() async {
  final initBasecoinAccounts = <Address, double>{0x1: 100000};
  final initStablecoinAccounts = <Address, double>{0x1: 100000};
  final initReservecoinAccounts = <Address, double>{0x1: 100000};

  // Load ~1-min historical data retrieved from Kaggle.com.
  final lines = File('./assets/adausd.csv').readAsLinesSync();

  final xrates = lines.skip(1).map((_) => _.split(',')).toList();
  final xrateLength = xrates.length;

  // It emulates an 12-min Oracle, on averate
  final skipNext = 12;

  final xrate = double.tryParse(xrates.first[1])!;
  final historySize = xrateLength ~/ skipNext;

  final oracle = SimpleMapOracle();
  oracle.updateConversionRate(PegCurrency, BaseCoin, xrate);

  // 3% commission a.k.a fee0, it is the `fee` in minimal Djed
  final fee0 = 0.03;

  // Keep in mind that `r_opt > r_peg > 1` and `r_peg = r_min`
  // 150% peg reserves ratio
  final r_peg = 1.5;
// 400% optimal reserves ratio
  final r_opt = 4.0;
  // the minimum price of Shen e.g., 1/2 of ADA i.e., 2 Shen = 1 ADA
  final pt_min = 0.5;

  // fee deviation coefficients
  final k_rm_def = 1.1;
  final k_rr_def = 1.1;
  final k_sm_def = 1.1;
  final k_sr_def = 1.1;

  final initialRC = 100000.0; // 10K Shen
  final initialSC = 100000.0; // 10K Djed initially

  // The initial reserve is the initial Djed at xrate price
  // FIXME: refactor everything  to BigInt .ceilToDouble();
  final initialReserves = (initialSC / xrate);

  final contract = ExtendedDjed(oracle, fee0, pt_min, r_peg, r_opt, k_rm_def,
      k_rr_def, k_sm_def, k_sr_def, initialReserves, initialSC, initialRC);

  final ledger = SimpleLedger(contract, initBasecoinAccounts,
      initStablecoinAccounts, initReservecoinAccounts);
  final players = <Player>[ReservecoinTrader(0x1), StablecoinUser(0x1)];

  Simulator(ledger, HistoricalGame(xrates, skipNext), players, historySize)
      .run();
}

/// `r_opt > r_peg > 1`
///
/// Reference: [Djed: A Formally Verified Crypto-Backed Pegged Algorithmic Stablecoin](https://eprint.iacr.org/2021/1069.pdf)
///
/// Operations:
/// 1. `buyStablecoins` : mints new SCs, increasing reserves, but decreasing reserve ratio.
/// 2. `sellStablecoins`: burns SCs, paying back from reserves, decreasing reserves and increasing reserve ratio.
/// 3. `buyReservecoins` : mint new RCs, increasing both, reservers and reserve ratio, but dilutes relative shares of existing RC holders.
/// 4. `sellReservecoins`: burn RCs, paying back from reserves, decreases the reserve ratio and increase relative shares of exisitn RC holder.
class HistoricalGame extends Environment {
  HistoricalGame(this.xrates, this.skip);
  final List<List<String>> xrates;
  final int skip;

  @override
  Ledger newRoundCallback(Ledger ledger, Address round) {
    final oldRate =
        ledger.contract.oracle.conversionRate(PegCurrency, BaseCoin);

    final newRate = double.tryParse(xrates[(round + 1) * skip][1])!;

    final contract = ledger.contract;
    contract.oracle.updateConversionRate(PegCurrency, BaseCoin, newRate);

    var tp = contract.targetPrice;
    var ap = newRate;
    print(
        'P_sc: $ap, Pt_sc: tp, Ln:  ${contract.normLiabilities()}, Lt: ${contract.targetLiabilities()}');

    //logger.trace('Bank state: ' + /** dateTime+ */' R: ' + contract.getReservesAmount + ', Nsc: ' + contract.getStablecoinsAmount +', Nrc: ' + contract.getReservecoinsAmount + ', X-Rate diff: ' + math.abs(oldRate.toDouble - newRate) * 100 + '%')

    final ratio = contract.reservesRatio();

    if (ratio < 1.5) {
      print('Reserves ratio is below minimal limit!: ${ratio.toString()}');
    }
    if (ratio < 1.0) {
      print('CRITICAL: Reserves are below liabilities!: ${ratio.toString()}');
    }
    return ledger;
  }
}

///
/// Historical data represents the past trades meaning the result of pressure or forces of the market.
/// When the price goes higher the demand is higher then supply and vice versa.
///
/// In this game the nr. of RC traders is 10% of the SC traders. Though their number is less than other traders
/// they must maintaing the reserve coin balance.
///
/// Dynamic fee is equal /w `bankFee` when `r = r_opt` and increases when reserve ratio is away from `r_opt`.
/// This incentives the RC traders to maintain equlibirium.
///
/// The model is simple, when RCs goes below the target price e.g., 0.5 (2Shen  == 1 Djed) thie buying pressure is higher
/// then selling one and vice versa
///
/// @param address
////
class ReservecoinTrader extends Player {
  ReservecoinTrader(super.address);

  var _prevPrice = 0.0;

  @override
  List<Transaction> newRoundCallback(Ledger ledger, int round) {
    var myRCs = ledger.reservecoinAccounts[address] ?? 0;

    final currentPrice = ledger.contract.reservecoinNominalPrice();

    final targetPrice = ledger.contract.reservecoinDefaultPrice;
    //.reservecoinNominalPrice(nrc: 0);
    // if Nrc = 0 then default reserve coin price

    var buyingPressure = currentPrice != 0 ? targetPrice / currentPrice : 0.0;

    var amount = (buyingPressure * 20000);

    final txs = <Transaction>[];
    if (_prevPrice != 0 && buyingPressure >= 1.0) {
      print(
          'Reservecoin price is decreasing compared to the target price. $buyingPressure  Ptsc: $currentPrice, Buying: $amount RC');
      txs.add(BuyReservecoinTransaction(address, amount));
    } else if (_prevPrice != 0 && buyingPressure < 1.0) {
      print(
          'Reservecoin price is decreasing compared to the target price. $buyingPressure  Ptsc: $currentPrice, Selling: $amount RC');
      txs.add(SellReservecoinTransaction(address, amount));
    }

    _prevPrice = currentPrice;
    return txs;
  }
}

///
/// In this game we assume a 0 deposit of Djed that should increasingly grow to a 100M TVL
/// which is being maintainanced at that level.
/// There are 1000 stable coin trader which can have two times bigger SC holding than the average 100K
///
/// To be able to mint SC to reach the required TVL, the reserve coin traders must (mostly) buy and sell
/// RCs (Shen) independently of the marketprice of to base coin (ADA)
///
/// While the SC buyers/sellers should follow some historical SC grow similar to some other stable coins e.g., DAI or MakerDAO.
/// The initial market cap of the SC is 10K whihc will grow gradually to 100m in 200 days, therefore its
/// grow can be simulated as: `10K*x^200 = 100m` e.g., x=Surd[10000,200] ~= 1.0471285
///
///
/// @param address
////
///
class StablecoinUser extends Player {
  StablecoinUser(super.address);

  static const maxAmount = 100000000; //100M
  static const growth =
      53; // 5% more buy then selling to simulate constant 5% growth long term

  /// The TVL increases 0.5% per day meaning reaches 100M
  @override
  List<Transaction> newRoundCallback(Ledger ledger, int round) {
    var myStablecoins = ledger.stablecoinAccounts[address] ?? 0;
    final currentPrice =
        ledger.contract.oracle.conversionRate(PegCurrency, BaseCoin);

    var luck = Random().nextInt(100);

    final amount = 10000.0;

    final txs = <Transaction>[];

    if (myStablecoins == 0) {
      // Initial buy of 10K when there is enough RC

      print('Initial Stablecoin buy if amount Reserves allows it: $amount  SC');
      BuyStablecoinTransaction(address, amount);
    } else if (myStablecoins <= maxAmount) {
      final amount = myStablecoins * growth;
      if (luck <= growth) {
        print('Buying stablecoin: $amount SC');
        txs.add(BuyStablecoinTransaction(address, amount));
      } else {
        print('Selling stablecoin: $amount SC');
        txs.add(SellStablecoinTransaction(address, amount));
      }
    }

    return txs;
  }
}
