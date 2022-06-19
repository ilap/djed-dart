// ignore_for_file: non_constant_identifier_names

import 'package:djed/simulator.dart';
import 'package:djed/stablecoin.dart';

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
  List<Transaction> newRoundCallback(Ledger ledger, int round) {
    final myBaseCoins = ledger.basecoinAccounts[address] ?? 0;
    // buy stablecoins for 5% of available basecoins
    final amountSC = myBaseCoins *
        0.05 /
        ledger.contract.oracle.conversionRate(PegCurrency, BaseCoin);

    return <Transaction>[BuyStablecoinTransaction(address, amountSC)];
  }
}

class StablecoinSeller extends Player {
  StablecoinSeller(super.address);

  @override
  List<Transaction> newRoundCallback(Ledger ledger, int round) {
    final myStableCoins = ledger.basecoinAccounts[address] ?? 0;
    // sell 5% of stablecoins
    final amountSC = myStableCoins * 0.05;
    return <Transaction>[SellStablecoinTransaction(address, amountSC)];
  }
}

void main() {
  final initBasecoinAccounts = <Address, double>{0x1: 10, 0x2: 10};
  final initStablecoinAccounts = <Address, double>{0x2: 20};

  final bankFee = 0.03;
  final pegReservesRatio = 1.5;
  final optimalReserveRatio = 4.0;
  final reservecoinDefaultPrice = 0.5;

  final k_rm = 1.1; // fee deviation coeff for RC minting;
  final k_rr = 1.1; // fee deviation coeff for RC redeeming;
  final k_sm = 1.1; // fee deviation coeff for SC minting;
  final k_sr = 1.1; // fee deviation coeff for SC redeeming;

  final oracle = SimpleMapOracle();

  oracle.updateConversionRate(PegCurrency, BaseCoin, 0.2);

  final contract = ExtendedDjed(oracle, bankFee, reservecoinDefaultPrice,
      pegReservesRatio, optimalReserveRatio, k_rm, k_rr, k_sm, k_sr, 20, 60, 5);

  final ledger =
      SimpleLedger(contract, initBasecoinAccounts, initStablecoinAccounts, {});

  final players = <Player>[StablecoinBuyer(0x1), StablecoinSeller(0x2)];

  final env = BullMarketEnvironment();

  Simulator(ledger, env, players, 10).run();
}
