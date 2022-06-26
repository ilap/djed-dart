// ignore_for_file: non_constant_identifier_names

import 'dart:io';
import 'dart:math';
import 'dart:developer' as logging;

import 'package:djed/simulator.dart';
import 'package:djed/stablecoin.dart';

///
/// # Historical Minimal Game.
///
/// It is very similar to the historical extended game and the differences is only that is uses
/// minimal Djed.
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

  // 400% minimal peg reserves ratio
  final r_min = 4.0;
// 800% maximum peg reserves ratio
  final r_max = 8.0;
  // the minimum price of Shen e.g., 1/2 of ADA i.e., 2 Shen = 1 ADA
  final pt_min = 0.5;

  final initialRC = 100000.0; // 100K Shen
  final initialSC = 100000.0; // 100K Djed initially

  // The initial reserve is the initial Djed at xrate price
  // NOTE: refactor everything  to BigInt;
  final initialReserves = (initialSC * xrate + initialRC * pt_min);

  // Put enough money to buy stablecoins by the users. + 10BN ADA
  final initBasecoinAccounts = <Address, double>{
    0x1: initialReserves + 1000000000
  };
  final initStablecoinAccounts = <Address, double>{0x1: initialSC};
  final initReservecoinAccounts = <Address, double>{0x1: initialRC};

  final contract = MinimalDjed(oracle, fee0, pt_min, r_min, r_max,
      initialReserves, initialSC, initialRC);

  final ledger = SimpleLedger(contract, initBasecoinAccounts,
      initStablecoinAccounts, initReservecoinAccounts);

  // The player's order is important. 1st RC trader & then SC user.
  final players = <Player>[ReservecoinTrader(0x1), StablecoinUser(0x1)];

  Simulator(ledger, HistoricalGame(xrates, skip), players, historySize).run();
}

///
/// Copied from extended historical game
///
class HistoricalGame extends Environment {
  HistoricalGame(this.xrates, this.skip);
  final List<List<String>> xrates;
  final int skip;

  @override
  Ledger newRoundCallback(Ledger ledger, Address round) {
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

    final r_min = (contract as MinimalDjed).minReservesRatio;
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
/// Copied from extended historical game
///
class ReservecoinTrader extends Player {
  ReservecoinTrader(super.address);

  var _prevPrice = 0.0;

  @override
  List<Transaction> newRoundCallback(Ledger ledger, int round) {
    final currentPrice = ledger.contract.reservecoinNominalPrice();

    final r = ledger.contract.reservesRatio();
    final r_opt = (ledger.contract as MinimalDjed).minReservesRatio;

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
/// Copied from extended historical game
///
class StablecoinUser extends Player {
  StablecoinUser(super.address);

  // maxTVL of 100M Djed
  static const maxTVL = 100000000;

  // 15% more buys than sells to simulate constant growth long term
  static const growth = 65;

  /// The TVL increases around 1M day meaning reaches 100M
  @override
  List<Transaction> newRoundCallback(Ledger ledger, int round) {
    final myStablecoins = ledger.stablecoinAccounts[address] ?? 0;

    final rand = Random().nextInt(100);

    final lucky = myStablecoins > maxTVL ? 100 / rand : growth / rand;

    final amount = 10000.0;

    final List<Transaction> txs = (myStablecoins == 0)
        ? <Transaction>[BuyStablecoinTransaction(address, amount)]
        : (lucky >= 1)
            ? <Transaction>[BuyStablecoinTransaction(address, amount)]
            : <Transaction>[SellStablecoinTransaction(address, amount)];

    return txs;
  }
}
