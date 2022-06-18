import 'package:djed/ledger/ledger.dart';
import 'package:djed/ledger/transaction.dart';

abstract class Player {
  Player(this.address);

  final int address;
  Transaction newRoundCallback(Ledger ledger, int round);
}
