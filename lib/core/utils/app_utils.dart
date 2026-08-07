class AppUtils {
  static String normalizeArabicNumbers(String input) {
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    const englishDigits = '0123456789';
    String result = input;
    for (int i = 0; i < arabicDigits.length; i++) {
      result = result.replaceAll(arabicDigits[i], englishDigits[i]);
    }
    return result.trim();
  }

  static double? tryParseDouble(String input) {
    return double.tryParse(normalizeArabicNumbers(input));
  }

  static int? tryParseInt(String input) {
    return int.tryParse(normalizeArabicNumbers(input));
  }
}
