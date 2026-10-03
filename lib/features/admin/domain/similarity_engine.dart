import 'dart:math';

/// High-performance, pure Dart Arabic text normalization and composite
/// string similarity engine.
///
/// Combines Jaro-Winkler (optimized for Arabic dish prefixes and token shifts)
/// and Levenshtein (optimized for typos and suffix edits) to accurately flag
/// duplicate and near-duplicate meals in Cloud Firestore.
class SimilarityEngine {
  SimilarityEngine._();

  // Arabic Harakat (diacritics), Quranic marks, and Tatweel/Kashida
  static final RegExp _tashkeelRegex = RegExp(r'[\u064B-\u065F\u0670\u0640]');

  // Arabic punctuation marks located inside the Arabic Unicode block (\u0600-\u061F, \u066A-\u066D, \u06D4)
  static final RegExp _arabicPunctuationRegex =
      RegExp(r'[\u0600-\u061F\u066A-\u066D\u06D4]');

  // Unicode-safe regex: preserves Arabic letters, digits, and Latin letters; replaces punctuation
  static final RegExp _punctuationRegex = RegExp(r'[^\u0600-\u06FF\s0-9a-zA-Z]');

  // Whitespace collapsing regex
  static final RegExp _multiSpaceRegex = RegExp(r'\s+');

  // Definite article and preposition+article clitics, longest first so that a
  // shorter prefix can never shadow a longer one during token stripping
  static const List<String> _articlePrefixes = ['وبال', 'بال', 'وال', 'ال'];

  // Eastern Arabic and Perso-Arabic digit mapping
  static const Map<String, String> _arabicIndicDigits = {
    '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
    '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
    '۰': '0', '۱': '1', '۲': '2', '۳': '3', '۴': '4',
    '۵': '5', '۶': '6', '۷': '7', '۸': '8', '۹': '9',
  };

  /// Normalizes Arabic text for deduplication comparison:
  /// 1. Strips Tashkeel and Tatweel
  /// 2. Unifies Alef forms ([أإآٱ] -> ا)
  /// 3. Unifies Taa Marbuta (ة -> ه)
  /// 4. Unifies Alef Maqsura (ى -> ي)
  /// 5. Converts Arabic-Indic numerals to ASCII digits
  /// 6. Strips punctuation while preserving Arabic Unicode characters
  /// 7. Lowercases Latin characters
  /// 8. Collapses whitespace runs and trims
  static String normalizeArabic(String text) {
    if (text.isEmpty) return '';

    var result = text;

    // 1. Remove Tashkeel & Tatweel
    result = result.replaceAll(_tashkeelRegex, '');

    // 2. Unify Alef forms
    result = result.replaceAll(RegExp(r'[أإآٱ]'), 'ا');

    // 3. Unify Taa Marbuta to Haa
    result = result.replaceAll('ة', 'ه');

    // 4. Unify Alef Maqsura to Yaa
    result = result.replaceAll('ى', 'ي');

    // 5. Convert Arabic-Indic numerals
    _arabicIndicDigits.forEach((arDigit, enDigit) {
      result = result.replaceAll(arDigit, enDigit);
    });

    // 6. Strip non-alphanumeric punctuation (Unicode safe)
    result = result.replaceAll(_arabicPunctuationRegex, ' ');
    result = result.replaceAll(_punctuationRegex, ' ');

    // 7. Lowercase Latin characters
    result = result.toLowerCase();

    // 8. Collapse whitespace and trim
    return result.replaceAll(_multiSpaceRegex, ' ').trim();
  }

  /// Calculates Jaro-Winkler similarity between two strings.
  /// Result ranges from 0.0 (completely dissimilar) to 1.0 (exact match).
  static double jaroWinkler(String s1, String s2, {double p = 0.1, int maxL = 4}) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final len1 = s1.length;
    final len2 = s2.length;
    final matchWindow = max(0, (max(len1, len2) ~/ 2) - 1);

    final s1Matches = List<bool>.filled(len1, false);
    final s2Matches = List<bool>.filled(len2, false);

    var matches = 0;

    for (var i = 0; i < len1; i++) {
      final start = max(0, i - matchWindow);
      final end = min(len2 - 1, i + matchWindow);

      for (var j = start; j <= end; j++) {
        if (!s2Matches[j] && s1[i] == s2[j]) {
          s1Matches[i] = true;
          s2Matches[j] = true;
          matches++;
          break;
        }
      }
    }

    if (matches == 0) return 0.0;

    var transpositions = 0;
    var k = 0;
    for (var i = 0; i < len1; i++) {
      if (!s1Matches[i]) continue;
      while (!s2Matches[k]) {
        k++;
      }
      if (s1[i] != s2[k]) {
        transpositions++;
      }
      k++;
    }

    final t = transpositions / 2.0;
    final jaro = (matches / len1 + matches / len2 + (matches - t) / matches) / 3.0;

    // Winkler prefix bonus
    var l = 0;
    final limit = min(maxL, min(len1, len2));
    while (l < limit && s1[l] == s2[l]) {
      l++;
    }

    final jw = jaro + l * p * (1.0 - jaro);
    return jw.clamp(0.0, 1.0);
  }

  /// Calculates the Levenshtein edit distance between two strings using
  /// two-row dynamic programming (O(min(m, n)) space complexity).
  static int levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final a = s1.length < s2.length ? s1 : s2;
    final b = s1.length < s2.length ? s2 : s1;

    final m = a.length;
    final n = b.length;

    var previousRow = List<int>.generate(m + 1, (i) => i);
    var currentRow = List<int>.filled(m + 1, 0);

    for (var j = 1; j <= n; j++) {
      currentRow[0] = j;
      for (var i = 1; i <= m; i++) {
        final cost = (a[i - 1] == b[j - 1]) ? 0 : 1;
        currentRow[i] = min(
          currentRow[i - 1] + 1,
          min(
            previousRow[i] + 1,
            previousRow[i - 1] + cost,
          ),
        );
      }
      final temp = previousRow;
      previousRow = currentRow;
      currentRow = temp;
    }

    return previousRow[m];
  }

  /// Calculates the Levenshtein similarity ratio: 1.0 - (distance / max(len1, len2)).
  static double levenshteinSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final maxLen = max(s1.length, s2.length);
    final dist = levenshteinDistance(s1, s2);
    return (1.0 - (dist / maxLen)).clamp(0.0, 1.0);
  }

  /// Calculates the word-level Jaccard index between raw strings:
  /// 1. Normalizes both inputs via [normalizeArabic]
  /// 2. Splits each into whitespace-separated tokens, dropping empties
  /// 3. Returns |intersection| / |union|
  ///
  /// Returns 0.0 when either side has no tokens. Character-level metrics are
  /// blind to this, which is why short dish names sharing one generic word
  /// ("محشي كوسة" vs "محشي ورق عنب") still look alike: the overlap here is
  /// what tells us whether the two names are actually about the same food.
  static double tokenJaccardSimilarity(String s1, String s2) {
    final tokens1 = _tokenize(normalizeArabic(s1));
    final tokens2 = _tokenize(normalizeArabic(s2));

    if (tokens1.isEmpty || tokens2.isEmpty) return 0.0;

    final union = tokens1.union(tokens2);
    final intersection = tokens1.intersection(tokens2);

    return intersection.length / union.length;
  }

  /// Calculates composite similarity between raw strings:
  /// 1. Normalizes both inputs via [normalizeArabic]
  /// 2. Takes the stronger of JaroWinkler and LevenshteinSimilarity
  /// 3. Gates that character score by [tokenJaccardSimilarity] so that a thin
  ///    word overlap dampens the result instead of faking a duplicate
  ///
  /// Defensive guard: If both normalized strings are empty, returns 0.0.
  static double compositeSimilarity(String s1, String s2) {
    final norm1 = normalizeArabic(s1);
    final norm2 = normalizeArabic(s2);

    if (norm1.isEmpty || norm2.isEmpty) {
      return 0.0;
    }

    if (norm1 == norm2) return 1.0;

    final jw = jaroWinkler(norm1, norm2);
    final lev = levenshteinSimilarity(norm1, norm2);
    final charScore = max(jw, lev);

    // Raw inputs are passed through: tokenization normalizes internally.
    final tokenJaccard = tokenJaccardSimilarity(s1, s2);

    return tokenJaccard < 0.5 ? charScore * tokenJaccard : charScore;
  }

  /// Splits normalized text into whitespace-separated tokens, stripping the
  /// definite article clitics so that "بشاميل" and "بالبشاميل" collide. A
  /// prefix is only removed when the stem survives at 2+ characters, which
  /// keeps short words that merely begin with those letters intact.
  static Set<String> _tokenize(String normalized) {
    if (normalized.isEmpty) return <String>{};
    return normalized
        .split(' ')
        .where((token) => token.isNotEmpty)
        .map((token) {
          for (final prefix in _articlePrefixes) {
            if (token.startsWith(prefix) &&
                token.length - prefix.length >= 2) {
              return token.substring(prefix.length);
            }
          }
          return token;
        })
        .toSet();
  }

  /// Returns true if composite similarity meets or exceeds the given threshold (default 88%).
  static bool areSimilar(String s1, String s2, {double threshold = 0.88}) {
    return compositeSimilarity(s1, s2) >= threshold;
  }
}
