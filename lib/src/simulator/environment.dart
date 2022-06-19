// ignore_for_file: one_member_abstracts

import 'ledger/ledger.dart';

abstract class Environment {
  Ledger newRoundCallback(Ledger ledger, int round);
}
