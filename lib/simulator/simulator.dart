import 'package:djed/ledger/ledger.dart';
import 'player.dart';
import 'environment.dart';

class Simulator {
  Simulator(this._ledger, this.env, this.players, this.duration);

  Ledger _ledger;
  Ledger get ledger => _ledger;

  final Environment env;
  final List<Player> players;
  final int duration;

  void run() {
    for (var i = 0; i < duration; i++) {
      print('Starting round: $i');
      _ledger = env.newRoundCallback(ledger, i);

      //print(ledger.contract);

      final transactions = players.map((_) {
        final result = _.newRoundCallback(ledger, i);
        return result;
      });

      for (var tx in transactions) {
        /// Catch the proper error
        try {
          ledger.addTransaction(tx);
          print('Transaction applied: ${tx.toString()}');
        } catch (exception) {
          print('Transaction rejected: ${tx.toString()}');
        }
      }

      print('Ending round: $i');
      //print(ledger.contract);
    }

    print('End of simulation. ${ledger.contract}');
  }
}
