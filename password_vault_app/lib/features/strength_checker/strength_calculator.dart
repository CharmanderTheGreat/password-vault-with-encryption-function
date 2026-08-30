import 'dart:math';

enum StrengthLevel { veryWeak, weak, fair, strong, veryStrong }

class PasswordStrengthResult {
  final double entropyBits;
  final StrengthLevel level;
  final String label;
  final Duration estimatedCrackTimeOffline; // assuming a strong offline attacker

  PasswordStrengthResult({
    required this.entropyBits,
    required this.level,
    required this.label,
    required this.estimatedCrackTimeOffline,
  });
}

/// Calculates real entropy based on character pool size and length,
/// then estimates how long an offline brute-force attack would take
/// against a modern GPU cracking rig (order-of-magnitude estimate,
/// assumes ~10 billion guesses/sec for a fast unsalted hash — real
/// numbers vary a lot depending on the hashing algorithm used
/// server-side, this is meant as a rough guide, not a guarantee).
class StrengthCalculator {
  static const double _guessesPerSecond = 10000000000; // 10 billion/sec

  static PasswordStrengthResult calculate(String password) {
    if (password.isEmpty) {
      return PasswordStrengthResult(
        entropyBits: 0,
        level: StrengthLevel.veryWeak,
        label: 'Empty',
        estimatedCrackTimeOffline: Duration.zero,
      );
    }

    final poolSize = _estimatePoolSize(password);
    final entropyBits = password.length * (log(poolSize) / log(2));

    final totalCombinations = pow(2, entropyBits);
    final secondsToCrack = (totalCombinations / 2) / _guessesPerSecond; // average case

    final level = _levelForEntropy(entropyBits);

    return PasswordStrengthResult(
      entropyBits: entropyBits,
      level: level,
      label: _labelForLevel(level),
      estimatedCrackTimeOffline: _secondsToDuration(secondsToCrack),
    );
  }

  static int _estimatePoolSize(String password) {
    var pool = 0;
    if (password.contains(RegExp(r'[a-z]'))) pool += 26;
    if (password.contains(RegExp(r'[A-Z]'))) pool += 26;
    if (password.contains(RegExp(r'[0-9]'))) pool += 10;
    if (password.contains(RegExp(r'[^a-zA-Z0-9]'))) pool += 32;
    return pool == 0 ? 1 : pool;
  }

  static StrengthLevel _levelForEntropy(double bits) {
    if (bits < 28) return StrengthLevel.veryWeak;
    if (bits < 36) return StrengthLevel.weak;
    if (bits < 60) return StrengthLevel.fair;
    if (bits < 100) return StrengthLevel.strong;
    return StrengthLevel.veryStrong;
  }

  static String _labelForLevel(StrengthLevel level) {
    switch (level) {
      case StrengthLevel.veryWeak:
        return 'Very weak, easily guessed';
      case StrengthLevel.weak:
        return 'Weak, add more length or variety';
      case StrengthLevel.fair:
        return 'Fair, could be stronger';
      case StrengthLevel.strong:
        return 'Strong';
      case StrengthLevel.veryStrong:
        return 'Very strong';
    }
  }

  static Duration _secondsToDuration(double seconds) {
    if (seconds.isInfinite || seconds > 1e15) {
      return const Duration(days: 365 * 1000000); // effectively "forever"
    }
    return Duration(seconds: seconds.round());
  }
}
