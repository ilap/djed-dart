import 'dart:math';

import 'ledger.dart';

abstract class Transaction {
  String id = DateTime.now().millisecondsSinceEpoch.toString() +
      Random().nextInt(0xff).toString().padLeft(4, '0');
}

class TransferTransaction extends Transaction {
  TransferTransaction(this.from, this.to, this.amount, this.currency);

  final int from;
  final int to;
  final double amount;
  final CoinType currency;

  @override
  String toString() =>
      'TransferTransaction ($currency): $id, from: $from, to: $to, amount: $amount';
}

abstract class ContractCallTransaction extends Transaction {
  ContractCallTransaction(this.from);
  final int from;
}

class BuyStablecoinTransaction extends ContractCallTransaction {
  BuyStablecoinTransaction(super.from, this.amountSC);

  final double amountSC;

  @override
  String toString() =>
      'BuyStablecoinTransaction  : $id, from: $from, amountSC: $amountSC';
}

class SellStablecoinTransaction extends ContractCallTransaction {
  SellStablecoinTransaction(super.from, this.amountSC);

  final double amountSC;
  @override
  String toString() =>
      'SellStablecoinTransaction : $id, from: $from, amountSC: $amountSC';
}

class BuyReservecoinTransaction extends ContractCallTransaction {
  BuyReservecoinTransaction(super.from, this.amountRC);

  final double amountRC;
  @override
  String toString() =>
      'BuyReservecoinTransaction : $id, from: $from, amountSC: $amountRC';
}

class SellReservecoinTransaction extends ContractCallTransaction {
  SellReservecoinTransaction(super.from, this.amountRC);

  final double amountRC;

  @override
  String toString() =>
      'SellReservecoinTransaction: $id, from: $from, amountSC: $amountRC';
}
