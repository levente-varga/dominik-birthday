/// Configuration, text hints, and Completionist reward numbers for all 15 activation code key slots.
class KeySlotConfig {
  final int slotIndex;
  final String hintText;
  final int
  number; // Placeholder number for Completionist achievement reward (max 2 digits, editable by user)

  const KeySlotConfig({
    required this.slotIndex,
    required this.hintText,
    this.number = 0,
  });
}

/// Backward compatibility alias
typedef SlotHintConfig = KeySlotConfig;

/// Master configuration list for all 15 activation code slots.
const List<KeySlotConfig> keySlots = [
  KeySlotConfig(
    slotIndex: 3,
    number: 8,
    hintText: 'Giga money giga money\nGiga money jó,\n\nGiga money giga money\nHipp hápp hó!\n\nEz már majdnem guruló dollár!',
  ),
  KeySlotConfig(
    slotIndex: 13,
    number: 6,
    hintText: 'Szép a kilátás... Kár, hogy a lépcső nem ide vezet.',
  ),
  KeySlotConfig(
    slotIndex: 10,
    number: 7,
    hintText: 'Esti szürkületben fekete alakok sokasága dereng. '
        'Ki-ki egy kör, háromszög, vagy megharapott téglalap alakjában próbál '
        'kitartóan a magasban fennmaradni. Az úri nép mindeközben '
        'lakomázik, s mit sem tud az egészről. (Vagy csupán nem óhajt?)',
  ),
  KeySlotConfig(
    slotIndex: 0,
    number: 4,
    hintText: 'Kis köcsög, kis cigike.',
  ),
  KeySlotConfig(
    slotIndex: 8,
    number: 1,
    hintText: 'Vissza kéne már váltani ezt a sok flakont...',
  ),
  KeySlotConfig(
    slotIndex: 9,
    number: 5,
    hintText: 'Öt ajtó között',
  ),
  KeySlotConfig(
    slotIndex: 12,
    number: 3,
    hintText: 'Csád mellett, Hatvanpusztával szemben.',
  ),
  KeySlotConfig(
    slotIndex: 2,
    number: 2,
    hintText: 'Ennek a nyomnak az otthona\nAz előszoba feletti szoba\nEgyik tükor alatti pontja.\nVajon hogy kerülhetett oda?',
  ),
  KeySlotConfig(
    slotIndex: 11,
    number: 12,
    hintText: 'Ideges vagy? Nehéz a játék?\nTartanál egy szünetet?\nMenj és keresgélj az asztalod környékén.\nUtána meg vissza, chop chop!\nNyomod fasz!\nSok van még hátra!',
  ),
  KeySlotConfig(
    slotIndex: 1,
    number: 15,
    hintText: 'Egy hosszú éjszaka után ölelgetheted, így talán a titkát is elárulja neked.',
  ),
  KeySlotConfig(
    slotIndex: 6,
    number: 14,
    hintText: 'Egy fiók a középső szinten sokmindent rejthet, de mi lehet mögötte? Csak nehogy valaki levizelje!',
  ),
  KeySlotConfig(
    slotIndex: 14,
    number: 13,
    hintText: 'Kecske, de nem 4 lába van. Mit rejt az alja?',
  ),
  KeySlotConfig(
    slotIndex: 4,
    number: 11,
    hintText: 'Forró nyáron a legjobb barátunk lehet, de mit hordozhat még ez a szerkezet?',
  ),
  KeySlotConfig(
    slotIndex: 5,
    number: 10,
    hintText: 'Álmaink ilyen helyen szövődnek, ám ez a hely különleges. Az otthon melegéhez itt lehetünk a legközelebb.',
  ),
  KeySlotConfig(
    slotIndex: 7,
    number: 9,
    hintText: 'Életünk internet nélkül már elképzelhetetlen. De mi mást szolgáltathat még ez az eszköz',
  ),
];

/// Helper to get the configured number for a given slot index.
int getSlotNumber(int slotIndex) {
  final config = keySlots.firstWhere(
    (h) => h.slotIndex == slotIndex,
    orElse: () => KeySlotConfig(
      slotIndex: slotIndex,
      hintText: '',
      number: slotIndex + 1,
    ),
  );
  return config.number;
}

/// Helper to get the hint display text for a given slot index and unlocked key state.
String getSlotHintText(int slotIndex, List<String?> unlockedKeyChars) {
  final unlockedChar = (slotIndex >= 0 && slotIndex < unlockedKeyChars.length)
      ? unlockedKeyChars[slotIndex]
      : null;

  if (unlockedChar == null) {
    return '';
  }

  final config = keySlots.firstWhere(
    (h) => h.slotIndex == slotIndex,
    orElse: () => KeySlotConfig(
      slotIndex: slotIndex,
      hintText: 'Character #${slotIndex + 1}',
      number: slotIndex + 1,
    ),
  );

  return config.hintText;
}
