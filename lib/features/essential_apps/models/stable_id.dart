class StableId {
  static String fromParts(List<String> parts) {
    final String input = parts
        .map((String part) => part.trim().toLowerCase())
        .join('|');
    int hash = 0x811c9dc5;

    for (final int codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }

    return 'entry-${hash.toRadixString(16).padLeft(8, '0')}';
  }
}
