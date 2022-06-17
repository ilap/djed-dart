// ignore_for_file: one_member_abstracts

import 'package:djed/ledger/ledger.dart';

abstract class Environment {
  Ledger newRoundCallback(Ledger ledger, int round);
}
