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

Currently, there are three very simple simulations are in the `example` directory:
1. `simple_extended_game.dart`
2. `simple_minimal_game.dart`
3. `historical_game.dart`


### Simple minimal game
Thsi simple came just buys and sells the 5% of the available stablecoins for the 99% percent of the targetPrice.
### Simple extended game

Almost the same as above. The only difference is that it uses Extended Djed instead.
### Historical extended game
TBD

### Simulate a game
To run a predefined game simulation type the following into a terminal:
 
``` bash
$ git clone https://github.com/ilap/djed-dart
$ cd djed-dart && dart pub get
# Run a game simulation
$ dart example/historical_extended_game.dart
...
```



# Credits
- [Original Scala based prototype](https://github.com/input-output-hk/djed-stablecoin-prototype)
# References
- [Djed: A Formally Verified Crypto-Backed Pegged Algorithmic Stablecoin](https://eprint.iacr.org/2021/1069.pdf)

# License

[MIT License](https://github.com/ilap/pinenacl-dart/blob/master/LICENSE)
