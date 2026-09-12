/// Helper function that formats large numbers into shorter strings if possible.
///
/// Examples:
/// - 10,000,000 -> "10M"
/// - 1,500,000 -> "1.5M"
/// - 15,000 -> "15k"
/// - 15250 -> "15250"
/// - 1,000 -> "1k"
/// - 100 -> "100"
String formatShortNumber(num number) {
  final isNegative = number < 0;
  final absVal = number.abs();
  final originalStr = number is int
      ? number.toString()
      : (absVal == absVal.roundToDouble()
            ? (isNegative ? '-${absVal.toInt()}' : absVal.toInt().toString())
            : number.toString());

  const units = [(1000000000, 'B'), (1000000, 'M'), (1000, 'k')];

  for (final (scale, suffix) in units) {
    if (absVal >= scale) {
      final divided = absVal / scale;
      final formattedNum = _formatCleanDouble(divided);
      final candidate = '${isNegative ? '-' : ''}$formattedNum$suffix';

      // Only use the shortened format if it is strictly shorter than the original
      if (candidate.length < originalStr.length) {
        return candidate;
      }
    }
  }

  return originalStr;
}

String formatPercentage(double probability) {
  return '${_formatCleanDouble(probability * 100)}%';
}

String _formatCleanDouble(double val) {
  if (val == val.roundToDouble()) {
    return val.toInt().toString();
  }
  String s = val.toStringAsFixed(2);
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return s;
}

/// Helper function that formats numbers with comma thousands separators.
///
/// Examples:
/// - 10000000 -> "10,000,000"
/// - 1500000 -> "1,500,000"
/// - 15000 -> "15,000"
/// - 15250 -> "15,250"
/// - 1000 -> "1,000"
/// - 100 -> "100"
/// - 0 -> "0"
/// - -15000 -> "-15,000"
String formatWithCommas(num number) {
  final isNegative = number < 0;
  final absVal = number.abs();

  if (number is int || absVal == absVal.roundToDouble()) {
    final intStr = absVal.toInt().toString();
    final withCommas = intStr.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
    return isNegative ? '-$withCommas' : withCommas;
  }

  final parts = number.toString().split('.');
  final intPart = (isNegative ? parts[0].substring(1) : parts[0])
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
  final fracPart = parts.length > 1 ? '.${parts[1]}' : '';
  return '${isNegative ? '-' : ''}$intPart$fracPart';
}

extension ShortNumberExtension on num {
  /// Returns a shortened string representation of the number if possible.
  String toShortString() => formatShortNumber(this);

  /// Returns a comma-grouped string representation of the number.
  String toCommaString() => formatWithCommas(this);
}
