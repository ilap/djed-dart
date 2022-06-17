import 'package:djed/ledger/ledger.dart';
import 'package:djed/ledger/transaction.dart';
import 'package:djed/djed.dart';
import 'package:djed/simulator/player.dart';
import 'package:djed/simulator/environment.dart';
import 'package:djed/simulator/simulator.dart';

class BullMarketEnvironment extends Environment {
  @override
  Ledger newRoundCallback(Ledger ledger, Address round) {
    final oldRate =
        ledger.contract.oracle.conversionRate(PegCurrency, BaseCoin);
    final newRate = oldRate * 0.99;
    ledger.contract.oracle.updateConversionRate(PegCurrency, BaseCoin, newRate);
    print(
        'Updated conversion rate: ${PegCurrency.name}  ->  ${BaseCoin.name} : $oldRate -> $newRate');
    return ledger;
  }
}

class StablecoinBuyer extends Player {
  StablecoinBuyer(super.address);

  @override
  Transaction newRoundCallback(Ledger ledger, int round) {
    final myBaseCoins = ledger.basecoinAccounts[address] ?? 0;
    // buy stablecoins for 5% of available basecoins
    final amountSC = myBaseCoins *
        0.05 /
        ledger.contract.oracle.conversionRate(PegCurrency, BaseCoin);

    return BuyStablecoinTransaction(address, amountSC);
  }
}

class StablecoinSeller extends Player {
  StablecoinSeller(super.address);

  @override
  Transaction newRoundCallback(Ledger ledger, int round) {
    final myStableCoins = ledger.basecoinAccounts[address] ?? 0;
    // sell 5% of stablecoins
    final amountSC = myStableCoins * 0.05;
    return SellStablecoinTransaction(address, amountSC);
  }
}

void main() {
  final initBasecoinAccounts = <Address, double>{0x1: 10, 0x2: 10};
  final initStablecoinAccounts = <Address, double>{0x2: 20};

  final bankFee = 0.01;
  final minReserveRatio = 1.5;
  final maxReserveRatio = 4.0;
  final reservecoinDefaultPrice = 0.5;

  final oracle = MapOracle();

  oracle.updateConversionRate(PegCurrency, BaseCoin, 0.2);

  final contract = MinimalDjed(oracle, bankFee, reservecoinDefaultPrice,
      minReserveRatio, maxReserveRatio, 20, 60, 5);

  final ledger = SimpleLedger(
      contract, initBasecoinAccounts, initStablecoinAccounts, {});

  final players = <Player>[StablecoinBuyer(0x1), StablecoinSeller(0x2)];

  final env = BullMarketEnvironment();

  Simulator(ledger, env, players, 10).run();
}
