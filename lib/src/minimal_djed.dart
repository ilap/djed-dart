part of djed;

class MinimalDjed extends Djed {
  MinimalDjed(
      super.oracle,
      super.bankFee,
      super.reserveCoinDefaultPrice,
      this.minReservesRatio,
      this.maxReservesRatio,
      super.reserves,
      super.stablecoins,
      super.reservecoins);

  final double minReservesRatio;
  final double maxReservesRatio;

  @override
  double normLiabilities({double? R, double? nsc}) =>
      min(R ?? reserves, (nsc ?? stablecoins) * targetPrice);

  @override
  double reservecoinNominalPrice({double? R, double? nsc, double? nrc}) {
    R = R ?? reserves;
    nsc = nsc ?? stablecoins;
    nrc = nrc ?? reservecoins;
    return nrc != 0 ? equity(R: R, nsc: nsc) / nrc : reservecoinDefaultPrice;
  }

  @override
  double stablecoinNominalPrice({double? R, double? nsc}) {
    nsc = nsc ?? reservecoins;

    return nsc == 0
        ? targetPrice
        : min(targetPrice, normLiabilities(R: R, nsc: nsc) / nsc);
  }

  @override
  double calculateBasecoinsForMintedStablecoins(double amountSC) {
    /// Calculates how many basecoins a user should pay (including fee) to receive `amountSC` stablecoins
    final amountBaseToPay =
        amountSC * stablecoinNominalPrice(R: reserves, nsc: stablecoins);
    final feeToPay = amountBaseToPay * bankFee;
    return amountBaseToPay + feeToPay;
  }

  @override
  double calculateBasecoinsForMintedReservecoins(double amountRC) {
    /// Continuous price calculation. The aim is to recalculate the price after buying each smallest portion of the coin (like
    /// in previous version for iterative price calculation). But here we assume that the coin is divided infinitely. Thus we
    /// used mathematical analysis to obtain the precise formula.
    ///
    double calculateAmountToPay(
        double amount, double inputReserves, double inputReservecoins) {
      // FIXME: require(reservecoinNominalPrice(inputReserves, stablecoins, inputReservecoins) >= reservecoinDefaultPrice)

      final newReservecoins = inputReservecoins + amount;
      final l = normLiabilities(R: inputReserves, nsc: stablecoins);

      // BigDecimal doesn't allow fractional pow, so we use math.pow(Double,Double) as a workaround.
      // It shouldn't be a problem since we don't expect big numbers here. But it has a side effect of rounding decimal part of BigDecimals,
      // which may result in tiny inconsistencies of paid amounts if we split buy operation into several transactions compared to
      // the wholesale buy. This should be handled properly in the production implementation.
      final tmp1 = pow((newReservecoins / inputReservecoins).toDouble(),
          (1 + bankFee).toDouble());
      final tmp2 = inputReserves - l;
      final newReserves = tmp1 * tmp2 + l;
      return newReserves - inputReserves;
    }

    if (reservecoinNominalPrice() < reservecoinDefaultPrice) {
      final l = normLiabilities(R: reserves, nsc: stablecoins);
      final maxToBuyWithMinPrice =
          (l - reserves + reservecoins * reservecoinDefaultPrice) /
              (bankFee * reservecoinDefaultPrice);

      if (maxToBuyWithMinPrice >= amountRC) {
        return amountRC * reservecoinDefaultPrice * (1 + bankFee);
      } else {
        final toPayWithMinPrice =
            maxToBuyWithMinPrice * reservecoinDefaultPrice * (1 + bankFee);
        final toPayWithNominalPrice = calculateAmountToPay(
            amountRC - maxToBuyWithMinPrice,
            reserves + toPayWithMinPrice,
            reservecoins + maxToBuyWithMinPrice);
        return toPayWithMinPrice + toPayWithNominalPrice;
      }
    } else {
      return calculateAmountToPay(amountRC.toDouble(), reserves, reservecoins);
    }
  }

  @override
  double calculateBasecoinsForBurnedReservecoins(double amountRC) {
    final l = normLiabilities(R: reserves, nsc: stablecoins);
    final newReservecoins = reservecoins - amountRC;
    // FIXME: require(newReservecoins > 0);

    // BigDecimal doesn't allow fractional pow, so we use math.pow(Double,Double) as a workaround.
    // It shouldn't be a problem since we don't expect big numbers here. But it has a side effect of rounding decimal part of BigDecimals,
    // which may result in tiny inconsistencies of paid amounts if we split buy operation into several transactions compared to
    // the wholesale buy. This should be handled properly in the production implementation.
    final tmp1 = pow(newReservecoins / reservecoins, 1 - bankFee);
    final tmp2 = reserves - l;
    final newReserves = tmp1 * tmp2 + l;
    return reserves - newReserves;
  }

  @override
  double calculateBasecoinsForBurnedStablecoins(double amountSC) {
    final scValueInBase =
        amountSC * stablecoinNominalPrice(R: reserves, nsc: stablecoins);
    final collectedFee = scValueInBase * bankFee;
    final amountBaseToReturn = scValueInBase - collectedFee;
    return amountBaseToReturn;
  }

  @override
  double buyStablecoins(double amountSC) {
    // FIXME: require(amountSC > 0)

    final amountBase = calculateBasecoinsForMintedStablecoins(amountSC);

    final newReserves = reserves + amountBase;
    final newStablecoins = stablecoins + amountSC;
    //FIXME: assert(acceptableReserveChange(true, false, false, newReserves, newStablecoins));

    _reserves += amountBase;
    _stablecoins += amountSC;
    return amountBase;
  }

  @override
  double sellStablecoins(double amountSC) {
    // FIXME require(amountSC > 0)

    final amountBaseToReturn = calculateBasecoinsForBurnedStablecoins(amountSC);
    final newReserves = reserves - amountBaseToReturn;
    final newStablecoins = stablecoins - amountSC;
    // FIXME require(acceptableReserveChange(false, false, false, newReserves, newStablecoins))

    _reserves = newReserves;
    _stablecoins = newStablecoins;
    return amountBaseToReturn;
  }

  @override
  double buyReservecoins(double amountRC) {
    // require(amountRC > 0)

    final amountBase = calculateBasecoinsForMintedReservecoins(amountRC);
    final newReserves = reserves + amountBase;
    final newReservecoins = reservecoins + amountRC;
    // FIXME require(acceptableReserveChange(false, true, false, newReserves, stablecoins));

    _reserves = newReserves;
    _reservecoins = newReservecoins;
    return amountBase;
  }

  @override
  double sellReservecoins(double amountRC) {
    // FIXME require(amountRC > 0)

    final amountBaseToReturn =
        calculateBasecoinsForBurnedReservecoins(amountRC);

    final newReserves = reserves - amountBaseToReturn;
    final newReservecoins = reservecoins - amountRC;
    // require(acceptableReserveChange(false, false, true, newReserves, stablecoins))

    _reserves = newReserves;
    _reservecoins = newReservecoins;
    return amountBaseToReturn;
  }

  @override
  String toString() {
    return 'Minimal Djed Stablecoin state:\n'
        '\tBasecoin amount: $reserves\n'
        '\tStablecoin amount: $stablecoins\n'
        '\tReservecoin amount: $reservecoins\n'
        '\tStablecoin nominal price: ${stablecoinNominalPrice(R: reserves, nsc: stablecoins)}\n'
        '\tReservecoin nominal price: ${reservecoinNominalPrice(R: reserves, nsc: stablecoins, nrc: reservecoins)}\n'
        '\tReserve ratio: ${reservesRatio(R: reserves, nsc: stablecoins)}\n'
        '\tConversion rate(PegCurrency -> BaseCoin): $targetPrice';
  }

  /// There are two conditions for the acceptability of a reserve change:
  ///  * If we are minting stablecoins or burning reservecoins, the new reserves shouldn't drop below the minimum.
  ///  * If we are minting reservecoins, the new reserves shouldn't rise above the maximum.
  /// Note that the new reserves can go above the maximum when stablecoins are being sold.
  /// This ensures that stablecoin holders can always sell their stablecoins. The only effect on
  /// reservecoin holders when the reserves rise above the maximum is a reduction of the leverage of
  /// the reservecoins in relation to the base currency.
  bool acceptableReserveChange(
      bool mintsSC, bool mintsRC, bool burnsRC, double R, double nsc) {
    double maxReserve(double nsc) => maxReservesRatio * nsc * targetPrice;
    double minReserve(double nsc) => minReservesRatio * nsc * targetPrice;
    bool implies(bool a, bool b) => !a || b;
    return implies((mintsSC || burnsRC), (R >= minReserve(nsc))) &&
        implies(mintsRC, (R <= maxReserve(nsc)));
  }

  ///
  ///  Calculates how many basecoins should be paid for `amountRC` minted reservecoins.
  ///  Utilizes iterative price recalculation. Accuracy parameter defines how often the price is recalculated.
  ///  E.g., if `accuracy=1` the price is recalculated after minting each single coin, if `accuracy=10` the price is
  ///  recalculated after 0.1 coins.
  ///  The function is used mostly for testing purposes to cross-check the price calculation in the continuous setting.
  ///
  double calculateBasecoinsForMintedReservecoinsIter(int amountRC,
      {int accuracy = 1}) {
    var newReserves = reserves;
    var newReservecoins = reservecoins;
    var totalAmountBaseToPay = 0.0;

    for (var i = 0; i < amountRC * accuracy; i++) {
      final nomPrice = reservecoinNominalPrice(
          R: newReserves, nsc: stablecoins, nrc: newReservecoins);
      final price = max(nomPrice, reservecoinDefaultPrice);
      final amountBaseToPay = price * (1 + bankFee) / accuracy;
      newReserves += amountBaseToPay;
      newReservecoins += (1.0 / accuracy);
      totalAmountBaseToPay += amountBaseToPay;
    }

    return totalAmountBaseToPay;
  }

  ///
  /// Calculates how many basecoins should be returned for burning `amountRC` reservecoins.
  ///  Utilizes iterative price recalculation. Used mostly for testing purposes to cross-check the price calculation
  /// in the continuous setting.
  ///
  Future<double> calculateBasecoinsForBurnedReservecoinsIter(int amountRC,
      {int accuracy = 1}) async {
    var newReserves = reserves;
    var newReservecoins = reservecoins;
    var totalAmountBaseToReturn = 0.0;

    for (var i = 0; i < amountRC * accuracy; i++) {
      final price = reservecoinNominalPrice(
          R: newReserves, nsc: stablecoins, nrc: newReservecoins);
      final amountBase = price / accuracy;
      final amountBaseToReturn = amountBase * (1 - bankFee);
      newReserves -= amountBaseToReturn;
      newReservecoins -= (1.0 / accuracy);
      totalAmountBaseToReturn += amountBaseToReturn;
    }

    return totalAmountBaseToReturn;
  }
}
