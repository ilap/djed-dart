// ignore_for_file: non_constant_identifier_names

import 'dart:io';
import 'dart:math';
import 'dart:developer' as logging;

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
  // Load ~1-min historical data retrieved from Kaggle.com.
  final lines = File('./assets/adausd.csv').readAsLinesSync();

  final xrates = lines.skip(1).map((_) => _.split(',')).toList();
  final xrateLength = xrates.length;

  // It emulates an 12-min Oracle, on averate
  final skip = 12;

  // X-change rate is ADA2USD meaning 0.2c means 5ADA
  final xrate = 1.0 / double.tryParse(xrates.first[1])!;
  final historySize = xrateLength ~/ skip;

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
  final k_rm = 1.1;
  final k_rr = 1.1;
  final k_sm = 1.1;
  final k_sr = 1.1;

  final initialRC = 100000.0; // 10K Shen
  final initialSC = 100000.0; // 10K Djed initially

  // The initial reserve is the initial Djed at xrate price
  // NOTE: refactor everything  to BigInt .ceilToDouble();
  final initialReserves = (initialSC * xrate + initialRC * pt_min);

  // Put enough money to buy stablecoins by the users. + 10BN
  final initBasecoinAccounts = <Address, double>{
    0x1: initialReserves + 10000000000
  };
  final initStablecoinAccounts = <Address, double>{0x1: initialSC};
  final initReservecoinAccounts = <Address, double>{0x1: initialRC};

  final contract = ExtendedDjed(oracle, fee0, pt_min, r_peg, r_opt, k_rm, k_rr,
      k_sm, k_sr, initialReserves, initialSC, initialRC);

  final ledger = SimpleLedger(contract, initBasecoinAccounts,
      initStablecoinAccounts, initReservecoinAccounts);

  // The player's order is important. 1st RC trader & then SC user.
  final players = <Player>[ReservecoinTrader(0x1), StablecoinUser(0x1)];

  Simulator(ledger, HistoricalGame(xrates, skip), players, historySize).run();
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
    //final oldRate =
    //    ledger.contract.oracle.conversionRate(PegCurrency, BaseCoin);

    final xrate = xrates[(round + 1) * skip];
    final newRate = 1.0 / double.tryParse(xrate[1])!;
    final dateTime =
        DateTime.fromMillisecondsSinceEpoch(int.tryParse(xrate[0])!);

    final contract = ledger.contract;
    contract.oracle.updateConversionRate(PegCurrency, BaseCoin, newRate);

    final ratio = contract.reservesRatio();
    print(
        'Bank state: $dateTime  R: ${contract.reserves}, Nsc: ${contract.stablecoins},'
        ' Nrc: ${contract.reservecoins}, r: $ratio, x-rate: ${xrate[1]}');

    if (ratio < 1.5) {
      logging.log('Reserves ratio is below minimal limit!: $ratio');
    }
    if (ratio < 1.0) {
      logging.log('CRITICAL: Reserves are below liabilities!: $ratio}');
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
class ReservecoinTrader extends Player {
  ReservecoinTrader(super.address);

  var _prevPrice = 0.0;

  @override
  List<Transaction> newRoundCallback(Ledger ledger, int round) {
    //var myRCs = ledger.reservecoinAccounts[address] ?? 0;

    final currentPrice = ledger.contract.reservecoinNominalPrice();

    final r = ledger.contract.reservesRatio();
    final r_opt = (ledger.contract as ExtendedDjed).optimalReservesRatio;

    final buyingPressure = r / r_opt;

    var amount = (currentPrice * 1000);

    final txs = _prevPrice == 0
        ? <Transaction>[]
        : buyingPressure <= 1.0
            ? [BuyReservecoinTransaction(address, amount)]
            : [SellReservecoinTransaction(address, amount)];

    if (txs.isNotEmpty) {
      logging.log(
        txs[0].toString(),
      );
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
class StablecoinUser extends Player {
  StablecoinUser(super.address);

  // maxAMount of 100M Djed
  static const maxAmount = 100000000;

  // 15% more buys than sells to simulate constant growth long term
  static const growth = 65;

  /// The TVL increases around 1M day meaning reaches 100M
  @override
  List<Transaction> newRoundCallback(Ledger ledger, int round) {
    final myStablecoins = ledger.stablecoinAccounts[address] ?? 0;

    final rand = Random().nextInt(100);

    final lucky = myStablecoins > maxAmount ? 100 / rand : growth / rand;

    final amount = 10000.0;

    final List<Transaction> txs = (myStablecoins == 0)
        ? <Transaction>[BuyStablecoinTransaction(address, amount)]
        : (lucky >= 1)
            ? <Transaction>[BuyStablecoinTransaction(address, amount)]
            : <Transaction>[SellStablecoinTransaction(address, amount)];

    return txs;
  }
}
