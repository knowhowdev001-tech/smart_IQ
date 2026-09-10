/// Sri Lankan mobile number handling.
///
/// The verified MSISDN is the account identity and the same number the telco
/// rail charges (PRD 6.1), so it is normalised to one canonical form before
/// it ever leaves the client. The telco endpoint is then chosen from the
/// first three digits of that form, against a routing table the server owns
/// (PRD 7.2).
abstract final class Msisdn {
  /// Mobile prefixes in service in Sri Lanka, without the leading zero.
  /// This is a client-side sanity check only. The authoritative
  /// prefix-to-provider mapping lives in `msisdn_prefix_routing` and is
  /// editable without an app release.
  static const _mobilePrefixes = {
    '70', '71', '72', '74', '75', '76', '77', '78',
  };

  /// Reduces any accepted form to local `0XXXXXXXXX`.
  ///
  /// Accepts `+94771234567`, `94771234567`, `0771234567` and `771234567`,
  /// along with spaces, dashes and brackets, because users paste numbers in
  /// every one of those shapes.
  static String? normalise(String input) {
    var digits = input.replaceAll(RegExp(r'[^\d+]'), '');

    if (digits.startsWith('+94')) {
      digits = digits.substring(3);
    } else if (digits.startsWith('94') && digits.length == 11) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    digits = digits.replaceAll(RegExp(r'\D'), '');

    if (digits.length != 9) return null;
    if (!_mobilePrefixes.contains(digits.substring(0, 2))) return null;

    return '0$digits';
  }

  static bool isValid(String input) => normalise(input) != null;

  /// Groups a normalised number for display: `077 123 4567`.
  static String format(String input) {
    final normalised = normalise(input);
    if (normalised == null) return input;
    return '${normalised.substring(0, 3)} ${normalised.substring(3, 6)} '
        '${normalised.substring(6)}';
  }

  /// The `+94` form the SMS gateway expects.
  static String? toE164(String input) {
    final normalised = normalise(input);
    return normalised == null ? null : '+94${normalised.substring(1)}';
  }
}
