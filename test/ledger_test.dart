import 'package:test/test.dart';

import 'package:djed/ledger/ledger.dart';
import 'package:djed/ledger/transaction.dart';
import 'minimal_djed_test.dart';

void main() {
  final initBasecoinAccounts = <Address, double>{0x1: 5, 0x2: 10, 0x3: 3};
  final initStablecoinAccounts = <Address, double>{0x1: 50, 0x2: 30, 0x3: 7};
  final initReservecoinAccounts = <Address, double>{0x1: 1, 0x2: 2, 0x3: 3};

  Ledger createDefaultLedger() {
    final contract = MinimalDjedTest.createStablecoinContract(30, 87, 6);
    return SimpleLedger(contract, initBasecoinAccounts, initStablecoinAccounts,
        initReservecoinAccounts);
  }

  group('Ledger Simulator Test', () {
    test('transfer transaction', () {
      final ledger = createDefaultLedger();

      final tx1 = TransferTransaction(0x1, 0x2, 1.3, CoinType.baseCoin);
      expect(() => ledger.addTransaction(tx1), returnsNormally);

      assert(ledger.basecoinAccounts[0x1] == initBasecoinAccounts[0x1]! - 1.3);
      assert(ledger.basecoinAccounts[0x2] == initBasecoinAccounts[0x2]! + 1.3);
      // Map ar not comparable assert(ledger.stablecoinAccounts == initStablecoinAccounts);
      // assert(ledger.reservecoinAccounts == initReservecoinAccounts);

      final tx2 = TransferTransaction(0x2, 0x5, 10, CoinType.stableCoin);
      expect(() => ledger.addTransaction(tx2), returnsNormally);
      assert(
          ledger.stablecoinAccounts[0x2] == initStablecoinAccounts[0x2]! - 10);
      assert(ledger.stablecoinAccounts[0x5] == 10);
      //assert(ledger.reservecoinAccounts == initReservecoinAccounts);

      final tx3 = TransferTransaction(0x3, 0x1, 3, CoinType.reserveCoin);
      expect(() => ledger.addTransaction(tx3), returnsNormally);
      assert(
          ledger.reservecoinAccounts[0x3] == initReservecoinAccounts[0x3]! - 3);
      assert(
          ledger.reservecoinAccounts[0x1] == initReservecoinAccounts[0x1]! + 3);

      final badTxs = <Transaction>[
        TransferTransaction(0x1, 0x2, -1, CoinType.baseCoin),
        TransferTransaction(0x1, 0x2, 0, CoinType.stableCoin),
        TransferTransaction(0x0, 0x2, 1, CoinType.baseCoin),
        TransferTransaction(0x1, 0x2, 5, CoinType.reserveCoin)
      ];

      for (var tx in badTxs) {
        expect(() => ledger.addTransaction(tx), throwsException);
      }

      // check final ledger state
      assert(ledger.basecoinAccounts.length == 3);
      assert(ledger.basecoinAccounts[0x1] == initBasecoinAccounts[0x1]! - 1.3);
      assert(ledger.basecoinAccounts[0x2] == initBasecoinAccounts[0x2]! + 1.3);
      assert(ledger.basecoinAccounts[0x3] == initBasecoinAccounts[0x3]);
      assert(ledger.stablecoinAccounts.length == 4);
      assert(ledger.stablecoinAccounts[0x1] == initStablecoinAccounts[0x1]);
      assert(
          ledger.stablecoinAccounts[0x2] == initStablecoinAccounts[0x2]! - 10);
      assert(ledger.stablecoinAccounts[0x3] == initStablecoinAccounts[0x3]);
      assert(ledger.stablecoinAccounts[0x5] == 10);
      assert(ledger.reservecoinAccounts.length == 3);
      assert(
          ledger.reservecoinAccounts[0x1] == initReservecoinAccounts[0x1]! + 3);
      assert(ledger.reservecoinAccounts[0x2] == initReservecoinAccounts[0x2]);
      assert(
          ledger.reservecoinAccounts[0x3] == initReservecoinAccounts[0x3]! - 3);
    });

    test('buy stablecoins transaction', () {
      final ledger = createDefaultLedger();

      final tx1 = BuyStablecoinTransaction(0x1, 5);
      final amountBaseToPay =
          ledger.contract.calculateBasecoinsForMintedStablecoins(5);

      expect(() => ledger.addTransaction(tx1), returnsNormally);

      assert(ledger.basecoinAccounts[0x1] ==
          initBasecoinAccounts[0x1]! - amountBaseToPay);
      assert(
          ledger.stablecoinAccounts[0x1] == initStablecoinAccounts[0x1]! + 5);
      assert(ledger.contract.reserves == 30 + amountBaseToPay);
      assert(ledger.contract.stablecoins == 87 + 5);

      final badTxs = <Transaction>[
        BuyStablecoinTransaction(0x1, 100),
        BuyStablecoinTransaction(0x1, 0),
        BuyStablecoinTransaction(0x0, 5)
      ];

      for (var tx in badTxs) {
        expect(() => ledger.addTransaction(tx), throwsException);
      }

      assert(ledger.contract.reserves == 30 + amountBaseToPay);
      assert(ledger.contract.stablecoins == 87 + 5);
    });

    test('sell stablecoins transaction', () {
      final ledger = createDefaultLedger();
      final contract = ledger.contract;

      final tx1 = SellStablecoinTransaction(0x1, 10);
      final price = contract.stablecoinNominalPrice(
          R: contract.reserves, nsc: contract.stablecoins);
      final expectedBaseAmountToReturn = 10 * (1 - contract.bankFee) * price;

      expect(() => ledger.addTransaction(tx1), returnsNormally);

      assert(ledger.basecoinAccounts[0x1] ==
          initBasecoinAccounts[0x1]! + expectedBaseAmountToReturn);
      assert(
          ledger.stablecoinAccounts[0x1] == initStablecoinAccounts[0x1]! - 10);
      assert(ledger.contract.reserves == 30 - expectedBaseAmountToReturn);
      assert(ledger.contract.stablecoins == 87 - 10);

      final badTxs = <Transaction>[
        SellStablecoinTransaction(0x1, 100),
        SellStablecoinTransaction(0x1, 0),
        SellStablecoinTransaction(0x0, 5)
      ];

      for (var tx in badTxs) {
        expect(() => ledger.addTransaction(tx), throwsException);
      }

      assert(ledger.contract.stablecoins == 87 - 10);
    });

    test('buy reservecoins transaction', () {
      final ledger = createDefaultLedger();
      final contract = ledger.contract;

      final tx1 = BuyReservecoinTransaction(0x1, 2);
      final amountBaseToPay =
          contract.calculateBasecoinsForMintedReservecoins(2);

      expect(() => ledger.addTransaction(tx1), returnsNormally);

      assert(ledger.basecoinAccounts[0x1] ==
          initBasecoinAccounts[0x1]! - amountBaseToPay);
      assert(
          ledger.reservecoinAccounts[0x1] == initReservecoinAccounts[0x1]! + 2);

      assert(contract.reserves == 30 + amountBaseToPay);
      assert(contract.reservecoins == 6 + 2);

      final badTxs = <Transaction>[
        BuyReservecoinTransaction(0x1, 10),
        BuyReservecoinTransaction(0x1, 0),
        BuyReservecoinTransaction(0x0, 1)
      ];

      for (var tx in badTxs) {
        expect(() => ledger.addTransaction(tx), throwsException);
      }

      assert(contract.reservecoins == 6 + 2);
    });

    test('sell reservecoins transaction', () {
      final ledger = createDefaultLedger();
      final contract = ledger.contract;

      final amountRC = 1.5;
      final tx1 = SellReservecoinTransaction(0x3, amountRC);
      final expectedBaseAmountToReturn =
          contract.calculateBasecoinsForBurnedReservecoins(amountRC);

      expect(() => ledger.addTransaction(tx1), returnsNormally);

      assert(ledger.basecoinAccounts[0x3] ==
          initBasecoinAccounts[0x3]! + expectedBaseAmountToReturn);
      assert(ledger.reservecoinAccounts[0x3] ==
          initReservecoinAccounts[0x3]! - amountRC);
      assert(contract.reserves == 30 - expectedBaseAmountToReturn);
      assert(contract.reservecoins == 6 - amountRC);

      final badTxs = <Transaction>[
        SellStablecoinTransaction(0x1, 55),
        SellStablecoinTransaction(0x1, 0),
        SellStablecoinTransaction(0x0, 5)
      ];

      for (var tx in badTxs) {
        expect(() => ledger.addTransaction(tx), throwsException);
      }
      assert(contract.reservecoins == 6 - amountRC);
    });

    test('transactions history', () {
      final ledger = createDefaultLedger() as SimpleLedger;

      final txs = <Transaction>[
        TransferTransaction(0x1, 0x2, 1, CoinType.baseCoin),
        BuyStablecoinTransaction(0x3, 1),
        BuyStablecoinTransaction(0x1, 1000),
        SellReservecoinTransaction(0x2, 1)
      ];

      expect(() => ledger.addTransaction(txs[0]), returnsNormally);
      expect(() => ledger.addTransaction(txs[1]), returnsNormally);
      expect(() => ledger.addTransaction(txs[2]), throwsException);
      expect(() => ledger.addTransaction(txs[3]), returnsNormally);

      assert(ledger.transactionsHistory.length == 3);
      assert(ledger.transactionsHistory[0] == txs[0]);
      assert(ledger.transactionsHistory[1] == txs[1]);
      assert(ledger.transactionsHistory[2] == txs[3]);
    });
  });
}
