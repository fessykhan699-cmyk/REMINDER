import 'dart:math';

class IdGenerator {
  IdGenerator._();

  static final Random _random = Random();

  static String nextId([String prefix = 'id']) {
    final now = DateTime.now().microsecondsSinceEpoch;
    final entropy = _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return '$prefix-$now-$entropy';
  }
}
