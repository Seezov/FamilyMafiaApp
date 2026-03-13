import 'dart:math';

extension DoubleRounding on double {
  double roundTo(int decimals) {
    final factor = pow(10, decimals).toDouble();
    return (this * factor).round() / factor;
  }

  double roundTo2Digits() => roundTo(2);
}
