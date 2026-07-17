import 'dart:math';

/// Generates strong, random, DIFFERENT passwords for each account —
/// using a cryptographically secure random source (Random.secure()),
/// not the predictable default Random().
class PasswordGeneratorOptions {
  final int length;
  final bool includeUppercase;
  final bool includeLowercase;
  final bool includeNumbers;
  final bool includeSymbols;
  final bool avoidAmbiguousChars; // excludes things like l, 1, I, O, 0

  const PasswordGeneratorOptions({
    this.length = 20,
    this.includeUppercase = true,
    this.includeLowercase = true,
    this.includeNumbers = true,
    this.includeSymbols = true,
    this.avoidAmbiguousChars = true,
  });
}

class PasswordGenerator {
  static const _lower = 'abcdefghijklmnopqrstuvwxyz';
  static const _upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const _numbers = '0123456789';
  static const _symbols = '!@#\$%^&*()_+-=[]{}|;:,.<>?';
  static const _ambiguous = 'lI1O0';

  static String generate(PasswordGeneratorOptions options) {
    final random = Random.secure();
    var pool = '';

    if (options.includeLowercase) pool += _lower;
    if (options.includeUppercase) pool += _upper;
    if (options.includeNumbers) pool += _numbers;
    if (options.includeSymbols) pool += _symbols;

    if (pool.isEmpty) {
      throw ArgumentError('At least one character set must be enabled.');
    }

    if (options.avoidAmbiguousChars) {
      pool = pool.split('').where((c) => !_ambiguous.contains(c)).join();
    }

    // Guarantee at least one char from each *enabled* set, so a generated
    // 20-char password can't accidentally end up all-lowercase, etc.
    final required = <String>[];
    if (options.includeLowercase) required.add(_randomChar(_lower, random));
    if (options.includeUppercase) required.add(_randomChar(_upper, random));
    if (options.includeNumbers) required.add(_randomChar(_numbers, random));
    if (options.includeSymbols) required.add(_randomChar(_symbols, random));

    final remainingLength = options.length - required.length;
    final rest = List.generate(
      remainingLength < 0 ? 0 : remainingLength,
      (_) => pool[random.nextInt(pool.length)],
    );

    final allChars = [...required, ...rest];
    allChars.shuffle(random);

    return allChars.join().substring(0, options.length);
  }

  static String _randomChar(String set, Random random) {
    final filtered = set.split('').toList();
    return filtered[random.nextInt(filtered.length)];
  }
}
