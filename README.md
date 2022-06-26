[![Pub Version (stable)](https://img.shields.io/pub/v/djed?color=important&label=pub%20stable&logo=dart)](https://pub.dartlang.org/packages/djed)
[![Dart Test CI](https://github.com/ilap/djed-dart/actions/workflows/dart.yml/badge.svg)](https://github.com/ilap/djed-dart/actions/workflows/dart.yml)
# Dart implementation of Djed Stablecoin

Djed-Dart is the dart implementation of the official [`Scala` based Djed Stablecoin Prototype (`djed-stableccoin-prototype`)](https://github.com/input-output-hk/djed-stablecoin-prototype)


## Features

It contains almost all the original code's unittest and games. In addition, it has a historical ADA price based game featuring `Extended Djed`.

## Getting started

You need to have the `Dart SDK` and the `git` command installed on your local machine.


### Install and configure dart SDK
Follow the instructions at the [Official Dart's page](https://dart.dev/get-dart) or you can install it in a Linux/macOS shell compatible terminal, see details below:

``` bash
$ cd 

$ mkdir -p development && pushd  development

$ curl -so- https://storage.googleapis.com/dart-archive/channels/be/raw/latest/sdk/dartsdk-linux-x64-release.zip | tar -xzvf -
# x dart-sdk/
# x  dart-sdk/bin/
# ...

$ echo "export PATH=\"\$PATH:$PWD/dart-sdk\"" >> ~/.profile && . ~/.profile

# The command below should return successfully.
$ dart --version
Dart SDK version: 2.17.3 (stable) (Wed Jun 1 11:06:41 2022 +0200) on "macos_x64"
$ popd
```


## Usage

### Run examples
Currently, there are three very simple simulations are in the `example` directory:
1. [`simple_extended_game.dart`](example/simple_extended_game.dart)
2. [`simple_minimal_game.dart`](example/simple_minimal_game.dart)
3. [`historical_extended_game.dart`](example/historical_extended_game.dart)
4. [`historical_minimal_game.dart`](example/historical_minimal_game.dart)

### Run Test

``` bash
$ cd djed-dart
$ dart test -r expanded
...
00:11 +27: test/extended_djed_test.dart: Extended Djed Test buy reservecoins when bankFee or k_rm equals zero
00:14 +28: test/extended_djed_test.dart: Extended Djed Test sell reservecoins
00:14 +29: test/extended_djed_test.dart: Extended Djed Test sell reservecoins (1-st variant): initial and new reserve ratio are below peg
00:14 +30: test/extended_djed_test.dart: Extended Djed Test sell reservecoins (2-nd variant):initial reserve ratio is above peg but below optimum, new ratio is below peg
00:15 +31: test/extended_djed_test.dart: Extended Djed Test sell reservecoins (3-rd variant): initial reserve ratio above the optimum, new ratio is below the peg
00:16 +32: test/extended_djed_test.dart: Extended Djed Test sell reservecoins (4-th variant):initial and new reserve ratio are above peg but below optimum
00:17 +33: test/extended_djed_test.dart: Extended Djed Test sell reservecoins (5-th variant): initial reserve ratio is above the optimumnew ratio is above peg but below optimal level
00:17 +34: test/extended_djed_test.dart: Extended Djed Test sell reservecoins (6-th variant): initial and new reserve ratio are above the optimum
00:18 +35: test/extended_djed_test.dart: Extended Djed Test sell reservecoins when initial ratio at peg/optimum boundaries
00:18 +36: test/extended_djed_test.dart: Extended Djed Test sell reservecoins when base fee or k_rr equals zero
00:24 +37: All tests passed!
```

### Simple minimal game
This simple came just buys and sells the 5% of the available stablecoins for the 99% percent of the targetPrice.
### Simple extended game

Almost the same as above. The only difference is that it uses Extended Djed instead.
### Historical games (extended/minimal)
Check comments in the [historical extended game's example](example/historical_extended_game.dart)

### Simulate a game
To run a predefined game simulation type the following into a terminal:
 
``` bash
$ git clone https://github.com/ilap/djed-dart
$ cd djed-dart && dart pub get
# Run a game simulation
$ dart example/historical_extended_game.dart
...
Starting round: 47357
Bank state: 2022-06-03 19:43:00.000  R: 1001492699.8285034, Nsc: 237060000.0, Nrc: 1067843.0476931066, r: 2.424562032222123, x-rate: 0.57391
Transaction rejected: [BuyReservecoinTransaction : 16556297171200239, from: 1, amountRC: 551046.7289309289]
Transaction rejected: [BuyStablecoinTransaction  : 16556297171200178, from: 1, amountSC: 10000.0]
Ending round: 47357
End of simulation. Stablecoin state:
	Basecoin amount: 1001492699.8285034
	Stablecoin amount: 237060000.0
	Reservecoin amount: 1067843.0476931066
	Stablecoin nominal price: 1.7424334826018015
	Reservecoin nominal price: 551.0467289309289
	Reserve ratio: 2.424562032222123
	Conversion rate: PegCurrency ->  BaseCoin: 1.7424334826018015
```

# Credits
- [Original Scala based prototype](https://github.com/input-output-hk/djed-stablecoin-prototype)
# References
- [Djed: A Formally Verified Crypto-Backed Pegged Algorithmic Stablecoin](https://eprint.iacr.org/2021/1069.pdf)

# License

[MIT License](https://github.com/ilap/pinenacl-dart/blob/master/LICENSE)
