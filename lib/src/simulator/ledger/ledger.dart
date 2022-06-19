import 'package:djed/stablecoin.dart';
import 'transaction.dart';

enum CoinType { baseCoin, stableCoin, reserveCoin }

typedef Address = int;
typedef Accounts = Map<Address, double>;

abstract class Ledger {
  Ledger(this.contract, this.initBasecoinAccounts, this.initStablecoinAccounts,
      this.initReservecoinAccounts) {
    _basecoinAccounts = Map.from(initBasecoinAccounts);
    _stablecoinAccounts = Map.from(initStablecoinAccounts);
    _reservecoinAccounts = Map.from(initReservecoinAccounts);
  }

  final Djed contract;

  late Accounts _basecoinAccounts;
  late Accounts _stablecoinAccounts;
  late Accounts _reservecoinAccounts;

  final Accounts initBasecoinAccounts;
  final Accounts initStablecoinAccounts;
  final Accounts initReservecoinAccounts;

  /// NOTE: New map should be created by `Accounts.from()` for
  /// losing reference from the initializer maps
  Accounts get basecoinAccounts => _basecoinAccounts;
  Accounts get stablecoinAccounts => _stablecoinAccounts;
  Accounts get reservecoinAccounts => _reservecoinAccounts;

  void addTransaction(Transaction tx);
}

class SimpleLedger extends Ledger {
  SimpleLedger(super.contract, super.basecoinAccounts, super.stablecoinAccounts,
      super.reservecoinAccounts);

  final transactionsHistory = <Transaction>[];

  @override
  void addTransaction(Transaction tx) {
    switch (tx.runtimeType) {
      case TransferTransaction:
        Accounts accounts = {};
        tx as TransferTransaction;
        switch (tx.currency) {
          case CoinType.baseCoin:
            accounts = basecoinAccounts;
            break;
          case CoinType.stableCoin:
            accounts = stablecoinAccounts;
            break;
          case CoinType.reserveCoin:
            accounts = reservecoinAccounts;
            break;
        }

        final fromAmount = accounts[tx.from] ?? 0.0;
        final toAmount = accounts[tx.to] ?? 0;

        if (tx.amount <= 0 || fromAmount < tx.amount) {
          throw Exception('Bad TransferTransaction: $tx');
        }

        accounts[tx.from] = accounts[tx.from]! - tx.amount;
        accounts[tx.to] = toAmount + tx.amount;

        break;
      case BuyStablecoinTransaction:
        tx as BuyStablecoinTransaction;
        final amountBaseToPay =
            contract.calculateBasecoinsForMintedStablecoins(tx.amountSC);

        final bc = basecoinAccounts[tx.from] ?? 0;

        if (tx.amountSC <= 0 || bc < amountBaseToPay) {
          throw Exception('Bad BuyStablecoinTransaction: $tx');
        }

        var r = contract.buyStablecoins(tx.amountSC);
        if (r != amountBaseToPay) throw Exception('Something is dodgy here.');

        basecoinAccounts[tx.from] = bc - amountBaseToPay;
        stablecoinAccounts[tx.from] =
            tx.amountSC + (stablecoinAccounts[tx.from] ?? 0.0);

        break;
      case SellStablecoinTransaction:
        tx as SellStablecoinTransaction;
        final scAmount = stablecoinAccounts[tx.from] ?? 0.0;

        if (tx.amountSC <= 0 || scAmount < tx.amountSC) {
          throw Exception('Bad SellStablecoinTransaction: $tx');
        }
        final amountBaseReturned = contract.sellStablecoins(tx.amountSC);

        stablecoinAccounts[tx.from] = scAmount - tx.amountSC;
        basecoinAccounts[tx.from] =
            amountBaseReturned + (basecoinAccounts[tx.from] ?? 0);

        break;
      case BuyReservecoinTransaction:
        tx as BuyReservecoinTransaction;
        final bcAmount = basecoinAccounts[tx.from] ?? 0;

        final amountBaseToPay =
            contract.calculateBasecoinsForMintedReservecoins(tx.amountRC);
        if (tx.amountRC <= 0 || bcAmount < amountBaseToPay) {
          throw Exception('Bad BuyReservecoinTransaction: $tx');
        }
        if (contract.buyReservecoins(tx.amountRC) != amountBaseToPay) {
          assert(false,
              "Expected amount is not equal to the actual. Something is wrong with the code!!!");
        }

        basecoinAccounts[tx.from] = bcAmount - amountBaseToPay;
        reservecoinAccounts[tx.from] =
            tx.amountRC + (reservecoinAccounts[tx.from] ?? 0);

        break;
      case SellReservecoinTransaction:
        tx as SellReservecoinTransaction;
        final amount = reservecoinAccounts[tx.from] ?? 0;

        if (tx.amountRC <= 0 || amount < tx.amountRC) {
          throw Exception('Bad SellReservecoinTransaction: $tx');
        }

        final amountBaseReturned = contract.sellReservecoins(tx.amountRC);
        reservecoinAccounts[tx.from] = amount - tx.amountRC;
        basecoinAccounts[tx.from] =
            amountBaseReturned + (basecoinAccounts[tx.from] ?? 0);

        break;
    }

    transactionsHistory.add(tx);
  }
}
