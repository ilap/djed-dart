import 'ledger/ledger.dart';
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
    print(ledger.contract);

    for (var i = 0; i < duration; i++) {
      print('Starting round: $i');
      _ledger = env.newRoundCallback(ledger, i);

      for (var player in players) {
        // It's a one length or empty  list
        final txs = player.newRoundCallback(ledger, i);
        if (txs.isNotEmpty) {
          try {
            ledger.addTransaction(txs.first);
            print('Transaction applied: ${txs.toString()}');
          } catch (exception) {
            print('Transaction rejected: ${txs.toString()}');
          }
        }
      }

      print('Ending round: $i');
      //print(ledger.contract);
    }

    print('End of simulation. ${ledger.contract}');
  }
}
