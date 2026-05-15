import 'dart:math';

/// Generates a RFC 4122 version-4 UUID using cryptographically secure random
/// bytes. No external package required — uses dart:math Random.secure().
String generateUuidV4() {
  final rng = Random.secure();
  final b = List<int>.generate(16, (_) => rng.nextInt(256));

  // Set version 4 (bits 4-7 of byte 6)
  b[6] = (b[6] & 0x0f) | 0x40;

  // Set variant 1 (bits 6-7 of byte 8)
  b[8] = (b[8] & 0x3f) | 0x80;

  String hex(int n) => n.toRadixString(16).padLeft(2, '0');

  return '${hex(b[0])}${hex(b[1])}${hex(b[2])}${hex(b[3])}'
      '-${hex(b[4])}${hex(b[5])}'
      '-${hex(b[6])}${hex(b[7])}'
      '-${hex(b[8])}${hex(b[9])}'
      '-${hex(b[10])}${hex(b[11])}${hex(b[12])}${hex(b[13])}${hex(b[14])}${hex(b[15])}';
}
