// ignore_for_file: non_constant_identifier_names

part of djed;

class ExtendedDjed extends Djed {
  ExtendedDjed(
      super.oracle,
      super.bankFee,
      super.reserveCoinDefaultPrice,
      this.pegReservesRatio,
      this.optimalReservesRatio,
      this.k_rm,
      this.k_rr,
      this.k_sm,
      this.k_sr,
      super.reserves,
      super.stablecoins,
      super.reservecoins);

  final double pegReservesRatio;
  final double optimalReservesRatio;
  final double k_rm;
  final double k_rr;
  final double k_sm;
  final double k_sr;

  @override
  double normLiabilities({double? R, double? nsc}) =>
      stablecoinNominalPrice(R: (R ?? reserves), nsc: (nsc ?? stablecoins)) *
      (nsc ?? stablecoins);

  @override
  double stablecoinNominalPrice({double? R, double? nsc}) {
    R = R ?? reserves;
    nsc = nsc ?? stablecoins;

    return nsc == 0
        ? targetPrice
        : min(1.0, reservesRatio(R: R, nsc: nsc) / pegReservesRatio) *
            targetPrice;
  }

  @override
  double reservecoinNominalPrice({double? R, double? nsc, double? nrc}) {
    R = R ?? reserves;
    nsc = nsc ?? stablecoins;
    nrc = nrc ?? reservecoins;

    return nrc != 0 ? equity(R: R, nsc: nsc) / nrc : reservecoinDefaultPrice;
  }

  double calculateBasecoinsForMintedStablecoinsIter(double amountSC,
      {int accuracy = 1}) {
    require(reservesRatio() > pegReservesRatio);
    var newReserves = reserves;
    var newStablecoins = stablecoins;
    var totalAmountBaseToPay = 0.0;

    double fee(double R, double nsc) {
      final ratio = reservesRatio(R: R, nsc: nsc);

      final additionalFee = ratio < optimalReservesRatio
          ? k_sm *
              (nsc * targetPrice * optimalReservesRatio - R) /
              (nsc * targetPrice * optimalReservesRatio)
          : 0.0;

      return bankFee + additionalFee;
    }

    for (var i = 0; i < amountSC * accuracy; i++) {
      final price = stablecoinNominalPrice(R: newReserves, nsc: newStablecoins);
      final amountBase = price / accuracy;
      final amountBaseToPay =
          amountBase * (1 + fee(newReserves, newStablecoins));

      newReserves += amountBaseToPay;
      newStablecoins += (1.0 / accuracy);
      require(reservesRatio(R: newReserves, nsc: newStablecoins) >=
          pegReservesRatio);
      totalAmountBaseToPay += amountBaseToPay;
    }

    return totalAmountBaseToPay;
  }

  @override
  double calculateBasecoinsForMintedStablecoins(double amountSC) {
    require(reservesRatio() > pegReservesRatio);
    final Pt_sc = targetPrice;

    double calculateAmountWithDynamicFee(double nsc0, double R0, double t) {
      final K = k_sm / optimalReservesRatio;
      final one_plus_K = 1 + K;
      final P = Pt_sc * (1 + bankFee + k_sm);
      final Nsc0_plus_t = nsc0 + t;
      final C = (R0 - P * (nsc0 / one_plus_K)) * pow(nsc0, K);
      final x1 = P * (Nsc0_plus_t) / one_plus_K;
      final x2 = pow(Nsc0_plus_t, K);
      return x1 + (C / x2) - R0;
    }

    var amountBasecoinsToPay = 0.0;
    if (reservesRatio() > optimalReservesRatio) {
      // calculating how much SCs need to be bought to decrease ratio to optimal level
      final amountToOptimum =
          (reserves - optimalReservesRatio * Pt_sc * stablecoins) /
              (Pt_sc * (optimalReservesRatio - 1 - bankFee));
      if (amountToOptimum >= amountSC) {
        amountBasecoinsToPay = Pt_sc * (1 + bankFee) * amountSC;
      } else {
        final amountWithbankFee = Pt_sc * (1 + bankFee) * amountToOptimum;
        final Nsc0 = stablecoins + amountToOptimum;
        final R0 = reserves + amountWithbankFee;
        final t = amountSC - amountToOptimum;
        amountBasecoinsToPay =
            amountWithbankFee + calculateAmountWithDynamicFee(Nsc0, R0, t);
      }
    } else {
      amountBasecoinsToPay = calculateAmountWithDynamicFee(
          stablecoins, reserves, amountSC.toDouble());
    }

    // sanity check
    final newReserveRatio = reservesRatio(
        R: reserves + amountBasecoinsToPay, nsc: stablecoins + amountSC);
    require(newReserveRatio >= pegReservesRatio,
        msg: 'The formulas are not suitable if ratio falls below optimum.');

    return amountBasecoinsToPay;
  }

  double calculateBasecoinsForMintedReservecoinsIter(double amountRC,
      {int accuracy = 1}) {
    require(amountRC > 0);
    var newReservecoins = reservecoins;
    var newReserves = reserves;
    var totalAmountBasecoinsToPay = 0.0;

    double fee(double R, double nsc) {
      final ratio = reservesRatio(R: R, nsc: nsc);

      final additionalFee = ratio >= optimalReservesRatio
          ? k_rm *
              (R - nsc * targetPrice * optimalReservesRatio) /
              (nsc * targetPrice * optimalReservesRatio)
          : 0.0;
      return bankFee + additionalFee;
    }

    // we need to track how many basecoins to pay for each peace of reservecoin
    double basecoinsAmount(double R, double nsc, double nrc) {
      final price = reservecoinNominalPrice(R: R, nsc: nsc, nrc: nrc);
      return price * (1 + fee(R, nsc));
    }

    for (var i = 0; i < amountRC * accuracy; i++) {
      final amountBasecoinsToPay =
          basecoinsAmount(newReserves, stablecoins, newReservecoins) / accuracy;
      newReservecoins += 1.0 / accuracy;
      newReserves += amountBasecoinsToPay;
      totalAmountBasecoinsToPay += amountBasecoinsToPay;
    }

    return totalAmountBasecoinsToPay;
  }

  @override
  double calculateBasecoinsForMintedReservecoins(double amountRC) {
    require(amountRC > 0);
    final R0 = reserves;
    final Nrc0 = reservecoins;
    final Nrc0_plus_N_div_Nrc0 = (Nrc0 + amountRC) / Nrc0;
    final one_plus_fee0 = 1 + bankFee;
    final Lt = targetLiabilities(nsc: stablecoins);
    final A = optimalReservesRatio /
        (optimalReservesRatio * (one_plus_fee0 - k_rm) + k_rm);

    double calculateVariant1() {
      final X = (1 - 1 / pegReservesRatio) * one_plus_fee0;
      return pow(Nrc0_plus_N_div_Nrc0, X) * R0;
    }

    double calculateVariant2() {
      final X = 1 / (1 - 1 / pegReservesRatio);
      final rpeg_mul_Lt = pegReservesRatio * Lt;
      final x1 = pow(Nrc0_plus_N_div_Nrc0.toDouble(), one_plus_fee0.toDouble());
      final x2 = pow((rpeg_mul_Lt / R0).toDouble(), (-X).toDouble());
      final x3 = rpeg_mul_Lt - Lt;
      return x1 * x2 * x3 + Lt;
    }

    double calculateVariant3() {
      final ropt_mul_Lt = optimalReservesRatio * Lt;
      final Y = 1 / one_plus_fee0;
      final X = Y / (1 - 1 / pegReservesRatio);
      final R0_pow_X = pow(R0.toDouble(), X.toDouble());
      final rpeg_min_one_pow_Y =
          pow((pegReservesRatio - 1).toDouble(), Y.toDouble());
      final ropt_min_one_pow_Y =
          pow((optimalReservesRatio - 1).toDouble(), Y.toDouble());
      final rpeg_mul_Lt_pow_X =
          pow((pegReservesRatio * Lt).toDouble(), X.toDouble());
      final x1 = Nrc0_plus_N_div_Nrc0 *
          R0_pow_X *
          rpeg_min_one_pow_Y /
          (rpeg_mul_Lt_pow_X * ropt_min_one_pow_Y);
      final Z = pow(x1.toDouble(), (1 / A).toDouble());
      final V = one_plus_fee0 / (ropt_mul_Lt - Lt);
      final E = one_plus_fee0 - k_rm;
      return (Z * E + V * Lt) / (V - Z * k_rm / ropt_mul_Lt);
    }

    double calculateVariant4() {
      final x1 = pow(Nrc0_plus_N_div_Nrc0.toDouble(), one_plus_fee0.toDouble());
      final x2 = R0 - Lt;
      return x1 * x2 + Lt;
    }

    double calculateVariant5() {
      final ropt_mul_Lt = optimalReservesRatio * Lt;
      final ropt_mul_Lt_min_Lt = ropt_mul_Lt - Lt;
      final x1 = (R0 - Lt) / ropt_mul_Lt_min_Lt;
      final x2 = pow(x1.toDouble(), (1 / one_plus_fee0).toDouble());
      final Z = pow((Nrc0_plus_N_div_Nrc0 * x2).toDouble(), (1 / A).toDouble());
      final V = one_plus_fee0 / ropt_mul_Lt_min_Lt;
      final E = one_plus_fee0 - k_rm;
      return (Z * E + V * Lt) / (V - Z * k_rm / ropt_mul_Lt);
    }

    double calculateVariant6() {
      final ropt_mul_Lt = optimalReservesRatio * Lt;
      final V = (one_plus_fee0 + (k_rm * (R0 - ropt_mul_Lt) / ropt_mul_Lt)) /
          (R0 - Lt);
      final Z = pow(Nrc0_plus_N_div_Nrc0.toDouble(), (1 / A).toDouble());
      final E = one_plus_fee0 - k_rm;
      return (Z * E + V * Lt) / (V - Z * k_rm / ropt_mul_Lt);
    }

    /*
      Depending on the initial and new reserve ratios we need to use different formulas.
      Initial ratio is known in advance, so we can eliminate using inappropriate formulas, but
      new ratio isn't known so we need to calculate all possible variants and then, by analyzing the results,
      pick only the correct one. See more details in paper.
     */
    final initReserveRatio = R0 / Lt;
    var newReserves = 0.0;
    if (initReserveRatio < pegReservesRatio) {
      final newReserves1 = calculateVariant1();
      final newReserveRatio1 = newReserves1 / Lt;
      final newReserves2 = calculateVariant2();
      final newReserveRatio2 = newReserves2 / Lt;
      final newReserves3 = calculateVariant3();
      final newReserveRatio3 = newReserves3 / Lt;

      if (newReserveRatio1 < pegReservesRatio) {
        newReserves = newReserves1;
      } else if (pegReservesRatio <= newReserveRatio2 &&
          newReserveRatio2 < optimalReservesRatio) {
        assert(pegReservesRatio <= newReserveRatio1);
        newReserves = newReserves2;
      } else {
        assert(optimalReservesRatio <= newReserveRatio2);
        assert(optimalReservesRatio <= newReserveRatio3);
        newReserves = newReserves3;
      }
    } else if (pegReservesRatio <= initReserveRatio &&
        initReserveRatio < optimalReservesRatio) {
      final newReserves4 = calculateVariant4();
      final newReserveRatio4 = newReserves4 / Lt;
      final newReserves5 = calculateVariant5();
      final newReserveRatio5 = newReserves5 / Lt;

      if (newReserveRatio4 < optimalReservesRatio) {
        newReserves = newReserves4;
      } else {
        assert(optimalReservesRatio <= newReserveRatio4);
        assert(optimalReservesRatio <= newReserveRatio5);
        newReserves = newReserves5;
      }
    } else {
      assert(optimalReservesRatio <= initReserveRatio);
      newReserves = calculateVariant6();
    }

    return newReserves - reserves;
  }

  /// Iterative price calculation for selling stablecoins.
  /// Used for testing purposes to cross-check continuous price calculation. */
  double calculateBasecoinsForBurnedStablecoinsIter(double amountSC,
      {int accuracy = 1}) {
    var newReserves = reserves;
    var newStablecoins = stablecoins;
    var totalAmountBaseToReturn = 0.0;

    double fee(double R, double nsc) {
      final ratio = reservesRatio(R: R, nsc: nsc);
      final additionalFee = ratio > optimalReservesRatio
          ? k_sr *
              (R - nsc * targetPrice * optimalReservesRatio) /
              (nsc * targetPrice * optimalReservesRatio)
          : 0.0;
      return bankFee + additionalFee;
    }

    for (var i = 0; i < amountSC * accuracy; i++) {
      final price = stablecoinNominalPrice(R: newReserves, nsc: newStablecoins);
      final amountBase = price / accuracy;
      final amountBaseToReturn =
          amountBase * (1 - fee(newReserves, newStablecoins));
      newReserves -= amountBaseToReturn;
      newStablecoins -= (1.0 / accuracy);
      totalAmountBaseToReturn += amountBaseToReturn;
    }

    return totalAmountBaseToReturn;
  }

  @override
  double calculateBasecoinsForBurnedStablecoins(double amountSC) {
    final Pt_sc = targetPrice;

    double calculateVariant1(double nsc0, double R0, double t) {
      final K = k_sr / optimalReservesRatio;
      final one_plus_K = 1 + K;
      final P = -Pt_sc * (1 - bankFee + k_sr);
      final Nsc0_min_t = nsc0 - t;
      final C =
          (R0 + P * (nsc0 / one_plus_K)) * pow(nsc0.toDouble(), K.toDouble());
      final x1 = -P * (Nsc0_min_t) / one_plus_K;
      final x2 = pow(Nsc0_min_t.toDouble(), K.toDouble());
      return R0 - (x1 + (C / x2));
    }

    double calculateVariant2(double t) {
      return t * Pt_sc * (1 - bankFee);
    }

    double calculateVariant3(double nsc0, double R0, double t) {
      final x1 = (1 - bankFee) / pegReservesRatio;
      final x2 = (nsc0 - t) / nsc0;
      final x = R0 * pow(x2.toDouble(), x1.toDouble());
      return R0 - x;
    }

    double initRatioAbovePeg(double nsc0, double R0, double t) {
      final rounded_ratio =
          double.tryParse(reservesRatio(R: R0, nsc: nsc0).toStringAsFixed(10))!;
      //NOTE: we do rounding to pass the check cause reservesRatio() might be
      //slightly less due to rounding issues when we do BigDecimal->Double
      //conversion in math.pow() on the previous step
      require(rounded_ratio >= pegReservesRatio);
      require(reservesRatio(R: R0, nsc: nsc0) < optimalReservesRatio);

      // calculating how many SCs need to be sold to increase ratio to optimal level
      final amountToOptimum = (R0 - optimalReservesRatio * Pt_sc * nsc0) /
          (Pt_sc * (1 - optimalReservesRatio - bankFee));
      if (amountToOptimum >= t) {
        return calculateVariant2(t);
      } else {
        final amountWithbankFee = calculateVariant2(amountToOptimum);
        final new_Nsc0 = nsc0 - amountToOptimum;
        final new_Nr0 = R0 - amountWithbankFee;
        final new_t = t - amountToOptimum;
        return amountWithbankFee + calculateVariant1(new_Nsc0, new_Nr0, new_t);
      }
    }

    double initRatioBelowPeg(double nsc0, double R0, double t) {
      require(reservesRatio(R: R0, nsc: nsc0) < pegReservesRatio);
      // calculating how many SCs need to be sold to increase ratio to peg level

      final d = (1 - bankFee) / pegReservesRatio;
      final x1 =
          pegReservesRatio * Pt_sc * pow(nsc0.toDouble(), d.toDouble()) / R0;

      final amountToPeg = nsc0 - pow(x1.toDouble(), (1 / (d - 1)).toDouble());
      if (amountToPeg > t) {
        return calculateVariant3(nsc0, R0, t);
      } else {
        final amountToReturn1 = calculateVariant3(nsc0, R0, amountToPeg);
        final new_R0 = R0 - amountToReturn1;
        final new_Nsc0 = nsc0 - amountToPeg;
        final new_t = t - amountToPeg;
        return amountToReturn1 + initRatioAbovePeg(new_Nsc0, new_R0, new_t);
      }
    }

    final amountBasecoinsToReturn = reservesRatio() >= optimalReservesRatio
        ? calculateVariant1(stablecoins, reserves, amountSC.toDouble())
        : reservesRatio() < pegReservesRatio
            ? initRatioBelowPeg(stablecoins, reserves, amountSC.toDouble())
            : initRatioAbovePeg(stablecoins, reserves, amountSC.toDouble());

    return amountBasecoinsToReturn;
  }

  /// Iterative price calculation for selling reservecoins.
  /// Used for testing purposes to cross-check continuous price calculation. */
  double calculateBasecoinsForBurnedReservecoinsIter(double amountRC,
      {int accuracy = 1}) {
    require(amountRC > 0);
    var newReservecoins = reservecoins;
    var newReserves = reserves;
    var totalAmountBasecoinsToReturn = 0.0;

    double fee(double R, double nsc) {
      final ratio = reservesRatio(R: R, nsc: nsc);

      final additionalFee = ratio < optimalReservesRatio
          ? k_rr *
              (nsc * targetPrice * optimalReservesRatio - R) /
              (nsc * targetPrice * optimalReservesRatio)
          : 0.0;
      return bankFee + additionalFee;
    }

    // we need to track how many basecoins to return for each peace of reservecoin
    double basecoinsAmount(double R, double nsc, double nrc) {
      final price = reservecoinNominalPrice(R: R, nsc: nsc, nrc: nrc);
      return price * (1 - fee(R, nsc));
    }

    for (var i = 0; i < amountRC * accuracy; i++) {
      final amountBasecoinsToReturn =
          basecoinsAmount(newReserves, stablecoins, newReservecoins) / accuracy;
      newReservecoins -= 1.0 / accuracy;
      newReserves -= amountBasecoinsToReturn;
      totalAmountBasecoinsToReturn += amountBasecoinsToReturn;
    }

    return totalAmountBasecoinsToReturn;
  }

  @override
  double calculateBasecoinsForBurnedReservecoins(double amountRC) {
    require(amountRC > 0);
    final R0 = reserves;
    final Nrc0 = reservecoins;
    final Nrc0_min_N_div_Nrc0 = (Nrc0 - amountRC) / Nrc0;
    final E = 1 - bankFee - k_rr;
    final Lt = targetLiabilities(nsc: stablecoins);
    final krr_div_Lt_ropt = k_rr / (Lt * optimalReservesRatio);
    final C = optimalReservesRatio / (optimalReservesRatio * E + k_rr);

    double calculateVariant1() {
      final V = (E + R0 * krr_div_Lt_ropt) / R0;
      final p = (pegReservesRatio - 1) * E / pegReservesRatio;
      final Z = pow(Nrc0_min_N_div_Nrc0.toDouble(), p.toDouble());
      return (Z * E) / (V - Z * (krr_div_Lt_ropt));
    }

    double calculateVariant2() {
      final rpeg_mul_Lt = pegReservesRatio * Lt;
      final x1 = (E + pegReservesRatio * k_rr / optimalReservesRatio);
      final x2 = E + R0 * krr_div_Lt_ropt;
      final x3 = (R0 - Lt) * x1 / ((rpeg_mul_Lt - Lt) * x2);
      final x4 = pow(x3.toDouble(), C.toDouble()) * Nrc0_min_N_div_Nrc0;
      final p = (E - (E / pegReservesRatio));
      final Z = pow(x4.toDouble(), p.toDouble());
      final V = x1 / rpeg_mul_Lt;
      return (Z * E) / (V - Z * (krr_div_Lt_ropt));
    }

    double calculateVariant3() {
      final ropt_min_one = optimalReservesRatio - 1;
      final one_min_fee0 = 1 - bankFee;

      final x1_1 = (R0 - Lt) / (ropt_min_one * Lt);
      final x1 = pow(x1_1.toDouble(), (1 / one_min_fee0).toDouble());
      final x2 = (optimalReservesRatio - 1) / (pegReservesRatio - 1);
      final x3_1 = E + pegReservesRatio * k_rr / optimalReservesRatio;
      final x3 = x3_1 / one_min_fee0;
      final x4 = pow((x2 * x3).toDouble(), C.toDouble());
      final x = Nrc0_min_N_div_Nrc0 * x1 * x4;
      final p = (E - (E / pegReservesRatio));
      final Z = pow(x.toDouble(), p.toDouble());
      final V = x3_1 / (pegReservesRatio * Lt);
      return (Z * E) / (V - Z * (krr_div_Lt_ropt));
    }

    double calculateVariant4() {
      final V = (E + R0 * krr_div_Lt_ropt) / (R0 - Lt);
      final Z = pow(Nrc0_min_N_div_Nrc0.toDouble(), (1 / C).toDouble());
      return (Z * E + V * Lt) / (V - Z * (krr_div_Lt_ropt));
    }

    double calculateVariant5() {
      final one_min_fee0 = 1 - bankFee;
      final roptLt_min_Lt = optimalReservesRatio * Lt - Lt;
      final x1_1 = (R0 - Lt) / roptLt_min_Lt;
      final x1 = pow(x1_1.toDouble(), (1 / one_min_fee0).toDouble());
      final Z = pow((Nrc0_min_N_div_Nrc0 * x1).toDouble(), (1 / C).toDouble());
      final V = one_min_fee0 / roptLt_min_Lt;
      return (Z * E + V * Lt) / (V - Z * (krr_div_Lt_ropt));
    }

    double calculateVariant6() {
      final x1 = pow(Nrc0_min_N_div_Nrc0.toDouble(), (1 - bankFee).toDouble());
      final x2 = R0 - Lt;
      return x1 * x2 + Lt;
    }

    /*
      Depending on the initial and new reserve ratios we need to use different formulas.
      Initial ratio is known in advance, so we can eliminate using inappropriate formulas, but
      new ratio isn't known so we need to calculate all possible variants and then, by analyzing the results,
      pick only the correct one. See more details in paper.
     */
    final initReserveRatio = R0 / Lt;
    var newReserves = 0.0;

    if (initReserveRatio < pegReservesRatio) {
      newReserves = calculateVariant1();
    } else if (pegReservesRatio <= initReserveRatio &&
        initReserveRatio < optimalReservesRatio) {
      final newReserves4 = calculateVariant4();
      final newReserveRatio4 = newReserves4 / Lt;
      if (newReserveRatio4 >= pegReservesRatio) {
        newReserves = newReserves4;
      } else {
        newReserves = calculateVariant2();
      }
    } else {
      final newReserves6 = calculateVariant6();
      final newReserveRatio6 = newReserves6 / Lt;
      if (newReserveRatio6 >= optimalReservesRatio) {
        newReserves = newReserves6;
      } else {
        final newReserves5 = calculateVariant5();
        final newReserveRatio5 = newReserves5 / Lt;
        if (newReserveRatio5 >= pegReservesRatio) {
          newReserves = newReserves5;
        } else {
          newReserves = calculateVariant3();
        }
      }
    }

    return reserves - newReserves;
  }

  /// Uses continuous price recalculation to define the price of minting stablecoins
  ///
  /// @param amountSC amount of stablecoins that will be minted
  /// @return amount of basecoins that is paid to the reserve
  @override
  double buyStablecoins(double amountSC) {
    require(amountSC > 0);
    require(reservesRatio() > pegReservesRatio);

    final baseCoinsToPay = calculateBasecoinsForMintedStablecoins(amountSC);

    final newReserves = reserves + baseCoinsToPay;
    final newStablecoins = stablecoins + amountSC;

    require(
        reservesRatio(R: newReserves, nsc: newStablecoins) >= pegReservesRatio);

    _reserves = newReserves;
    _stablecoins = newStablecoins;

    return baseCoinsToPay;
  }

  /// Iterative calculation of compensated reservecoins for selling stablecoins.
  /// Used for testing purposes to cross-check continuous calculation. */
  double calculateReservecoinsForBurnedStablecoinsIter(double amountSC,
      {int accuracy = 1}) {
    require(amountSC <= stablecoins);

    var newStablecoins = stablecoins;
    var newReservecoins = reservecoins;
    var newReserves = reserves;
    var totalAmountReservecoinsToReturn = 0.0;

    double reservecoinsSwapAmount(double R, double nsc, double nrc) {
      final k = min(1, reservesRatio(R: R, nsc: nsc) / pegReservesRatio);
      return ((1 - k) * targetPrice) /
          reservecoinNominalPrice(R: R, nsc: nsc, nrc: nrc);
    }

    // we also need to track how many basecoins are returned with each peace of
    //stablecoin, because it affects reserves
    double basecoinsAmount(double R, double nsc) {
      final price = stablecoinNominalPrice(R: R, nsc: nsc);
      return price / accuracy * (1 - bankFee);
    }

    for (var i = 0; i < amountSC * accuracy; i++) {
      final amountReservecoinsToReturn = (reservecoinsSwapAmount(
                  newReserves, newStablecoins, newReservecoins) /
              accuracy) *
          (1 - bankFee);
      newReservecoins += amountReservecoinsToReturn;
      newStablecoins -= (1.0 / accuracy);
      newReserves -= basecoinsAmount(newReserves, newStablecoins);
      totalAmountReservecoinsToReturn += amountReservecoinsToReturn;
    }

    return totalAmountReservecoinsToReturn;
  }

  double calculateReservecoinsForBurnedStablecoins(double amountSC) {
    require(amountSC <= stablecoins);

    if (reservesRatio() < pegReservesRatio) {
      final Pt_sc = targetPrice;
      final one_min_fee = 1 - bankFee;
      final inv_rpeg = (1 / pegReservesRatio);
      final d = inv_rpeg * one_min_fee;

      final xx1 = pegReservesRatio *
          Pt_sc *
          pow(stablecoins.toDouble(), d.toDouble()) /
          reserves;
      final amountToPeg =
          stablecoins - pow(xx1.toDouble(), (1 / (d - 1)).toDouble());

      final compensatedSC = min(amountToPeg, amountSC);

      final Nsc_min_N = stablecoins - compensatedSC;
      final one_min_inv_rpeg = 1 - inv_rpeg;
      final x1 = one_min_fee / one_min_inv_rpeg;
      final x2 = inv_rpeg * log((Nsc_min_N / stablecoins).toDouble());
      final one_min_d = 1 - d;
      final x3_1 = pow(Nsc_min_N.toDouble(), one_min_d.toDouble());
      final x3_2 = pow(stablecoins.toDouble(), one_min_d.toDouble());
      final x3_3 = pow(stablecoins.toDouble(), d.toDouble());
      final x3 = Pt_sc * x3_3 * (x3_1 - x3_2) / (reserves * one_min_d);
      final A = x1 * (x2 - x3);

      final newReservecoins = exp(A) * reservecoins;
      return newReservecoins - reservecoins;
    } else {
      return 0.0;
    } // if (reservesRatio() >= pegReserveRatio) reservecoins are not paid
  }

  /// Utilizes continous price recalculation
  ///
  /// @param amountSC amount of stablecoins to sell
  /// @return amount of basecoins withdrawn from the reserve
  @override
  double sellStablecoins(double amountSC) {
    // don't allow to sell all stablecoins to avoid division by zero when calculating reserves ratio
    require(amountSC > 0 && amountSC < stablecoins);

    final baseCoinsToReturn = calculateBasecoinsForBurnedStablecoins(amountSC);
    _reserves -= baseCoinsToReturn;
    _stablecoins -= amountSC;

    return baseCoinsToReturn;
  }

  /// If the system is under-collateralized (i.e., reserves ratio < pegReservesRatio),
  /// redemption is partially fulfilled in basecoins and the rest is returned in reservecoins.
  ///
  /// @param amountSC amount of stablecoins to sell
  /// @return returned number of Basecoins and Reservecoins
  Tuple2<double, double> sellStablecoinsWithSwap(double amountSC) {
    final reserveCoinsToReturn =
        calculateReservecoinsForBurnedStablecoins(amountSC.toDouble());
    final newReservecoins = reservecoins + reserveCoinsToReturn;

    final baseCoinsToReturn = sellStablecoins(amountSC);

    _reservecoins = newReservecoins;

    return Tuple2<double, double>(baseCoinsToReturn, reserveCoinsToReturn);
  }

  /// Iterative price calculation for minting reservecoins.
  /// Used for testing purposes to cross-check continuous price calculation. */

  @override
  double buyReservecoins(double amountRC) {
    require(amountRC > 0);

    final baseCoinsToPay = calculateBasecoinsForMintedReservecoins(amountRC);

    final newReserves = reserves + baseCoinsToPay;
    final newReservecoins = reservecoins + amountRC;

    _reserves = newReserves;
    _reservecoins = newReservecoins;

    return baseCoinsToPay;
  }

  @override
  double sellReservecoins(double amountRC) {
    require(amountRC > 0);

    final baseCoinsToReturn = calculateBasecoinsForBurnedReservecoins(amountRC);

    final newReserves = reserves - baseCoinsToReturn;
    final newReservecoins = reservecoins - amountRC;

    // don't allow to sell all reservecoins to be able to calculate nominal
    // RC price
    require(newReservecoins > 0);

    _reserves = newReserves;
    _reservecoins = newReservecoins;

    return baseCoinsToReturn;
  }
}
