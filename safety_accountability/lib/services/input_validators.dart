class InputValidators {
  static const String saMobileMessage =
      'Enter a valid South African mobile number, e.g. 071 234 5678 or +27 71 234 45678.';

  static final RegExp _email = RegExp(
    r"^[A-Za-z0-9._%+\-]+@(?:[A-Za-z0-9](?:[A-Za-z0-9\-]*[A-Za-z0-9])?\.)+[A-Za-z]{2,}$",
  );

  static bool isValidEmail(String? value) {
    final s = value?.trim() ?? '';
    return s.isNotEmpty && s.length <= 254 && _email.hasMatch(s);
  }

  /// Returns +27XXXXXXXXX, or null if this is not a valid South African mobile number.
  static String? normalizeSaMobile(String? raw) {
    var s = (raw ?? '').replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
    if (s.startsWith('+27')) {
      s = '0${s.substring(3)}';
    } else if (s.startsWith('0027')) {
      s = '0${s.substring(4)}';
    } else if (s.startsWith('27') && s.length == 11) {
      s = '0${s.substring(2)}';
    }
    if (!RegExp(r'^0\d{9}$').hasMatch(s)) return null;
        if (!RegExp(r'^0(6\d|7\d|8[1-5])\d{7}$').hasMatch(s)) return null;
    if (s.substring(3).split('').toSet().length == 1) return null;
    return '+27${s.substring(1)}';
  }
}