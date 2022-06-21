import 'dart:math';

import 'ledger.dart';

abstract class Transaction {
  Transaction(this.from, this.amount);

  String id = DateTime.now().millisecondsSinceEpoch.toString() +
      Random().nextInt(0xff).toString().padLeft(4, '0');

  final int from;
  final double amount;

  @override
  String toString() => '$runtimeType : $id, from: $from, amount: $amount';
}

abstract class ContractCallTransaction extends Transaction {
  ContractCallTransaction(super.from, super.amount);
}

class TransferTransaction extends Transaction {
  TransferTransaction(super.from, this.to, super.amount, this.currency);

  final int to;
  final CoinType currency;

  @override
  String toString() =>
      'TransferTransaction (${currency.name}): $id, from: $from, to: $to, amount: $amount';
}

class BuyStablecoinTransaction extends ContractCallTransaction {
  BuyStablecoinTransaction(super.from, super.amount);
}

class SellStablecoinTransaction extends ContractCallTransaction {
  SellStablecoinTransaction(super.from, super.amount);
}

class BuyReservecoinTransaction extends ContractCallTransaction {
  BuyReservecoinTransaction(super.from, super.amount);
}

class SellReservecoinTransaction extends ContractCallTransaction {
  SellReservecoinTransaction(super.from, super.amount);
}
