import 'ledger/ledger.dart';
import 'ledger/transaction.dart';

abstract class Player {
  Player(this.address);

  final int address;
  List<Transaction> newRoundCallback(Ledger ledger, int round);
}
