import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'config.dart';

class SpeedTypingConfig extends BaseGameConfig {
  static const int baseSentenceCount = 6;
  static const int sentenceCountReductionPerSkillLevel = 1;
  static const int minSentenceCount = 1;

  static const List<String> subjectsEasy = [
    'Dominik', 'Levi', 'Dominik', 'Dávid', 'Laló',
    'Tóbi', 'Boti', 'Ákos', 'Barnus', 'Petike',
    'Lölő', 'Vitya', 'Petya', 'Lázár', 'Orbán',
    'Kari Geri', 'Krisz', 'Doma', 'Orsi', 'Zsuzsi',
    'Ádám', 'Ricsi', 'Erik', 'Tomi', 'anyád',
    'Pócs', 'Bibi', 'Feró', 'Petike', 'Putin',
  ];
  static const List<String> subjectsHard = [
    'Szalai László', 'Erdélyi Dominik', 'Valaczkai Dávid Márk', 'Füller Lajos', 'Szűcs Barnabás Olivér',
    'Marozsák Tóbiás', 'Varga Levente', 'Peőcz Krisztián', 'Fekete Botond', 'Süle Ákos',
    'Radnai Márk', 'Micimackó', 'Németh Bazsi', 'Karácsony Geri', 'Donald John Trump',
    'Márky-Zay Péter', 'Orbán Viktor', 'Magyar Petike', 'Gulyás Geri', 'Forsthoffer Ágnes',
    'Gyurcsány Ferenc', 'Volodymyr Oleksandrovych Zelenskyy', 'Vladimir Vladimirovich Putin', 'Vitézy Dávid', 'Lázár János',
    'Thomas a gőzmozdony', 'Xi Jinping', 'Ulf Kristersson', 'Jeffrey Epstein', 'Toroczkai László',
    'Horthy Miklós', 'Mészáros Lőrinc', 'Pócs János', 'Benjamin Netanyahu', 'Mészáros Lőrinc',
    'Guttengéber Lilla',
  ];

  static const List<String> verbsEasy = [
    'leüti', 'lerúgja', 'lenézi', 'megveti', 'nézi',
    'ünnepli', 'utálja', 'szagolja', 'ellopja', 'imádja',
    'kísérti', 'elviszi', 'lehűti', 'bántja', 'eliminálja',
    'megeszi', 'megnyalja', 'kedveli', 'kívánja', 'figyeli',
    'üti', 'simizi', 'kamerázza', 'érzi', 'vakarja',
    'nyomja', 'ellöki', 'meglöki', 'kiosztja', 'eladja',
    'leveri', 'leszopja', 'kiszopja', 'leköpi', 'megnyálazza',
    'nyalja', 'tágítja', 'markolja', 'eszi', 'ujjazza',
  ];
  static const List<String> verbsHard = [
    'defenesztrálja', 'elnáspángolja', 'akadálymentesíti', 'agyonmagasztalja', 'átprogramozza',
    'áttanulmányozza', 'befecskendezi', 'beszappanozza', 'beolajozza', 'kitágítja',
    'lekenyerezi', 'dekontaminálja', 'destabilizálja', 'egybecsomagolja', 'eladományozza',
    'elmagyarázza', 'elspanyolosítja', 'forradalmasítja', 'gyarmatosítja', 'megtermékenyíti',
    'elkényezteti', 'megháromszorozza', 'hazakíséri', 'karamellizálja', 'kiegyensúlyozza',
    'kizsákmányolja', 'megerőszakolja', 'megcsiklandozza', 'megbotránkoztatja', 'megborotválja',
    'megfutamítja', 'megkereszteli', 'megnyomorgatja', 'meguzsonnáztatja', 'összecsavargatja',
    'összecsomagolja', 'összegömbölyíti', 'összegubancolja', 'szakvéleményezi', 'szétmarcangolja',
    'tehermentesíti', 'visszavásárolja', 'elárverezi', 'visszakanyarítja', 'össze-vissza veri',
    'arccsonton rúgja', 'gyomorszájon rúgja', 'megkergeti', 'inasba rakja', 'dühedelembe hozza',
    'megfingatja', 'megszaglássza', 'feldugja a seggébe', 'leszopja bő nyállal', 'egyben lenyeli',
    'megszopkodja', 'megfürdeti', 'felspanolja', 'szétmoggolja', 'magasról leszarja',
    'lehallgatja', 'szana-szét üti', 'lepoloskázza', 'eltulajdonítja', 'megmotoztatja',
    'elagyabugyálja', 'lehazugozza', 'elkülöníti', 'szétszortírozza', 'szemügyre veszi',
    'lekörözi aurafarmingban', 'megkörnyékezi', 'megversenyezteti',
    'felhúzza az ujjára', 'bottal üti a nyomát',
  ];

  static const Map<String, List<String>> adjectivesMapEasy = {
    'Size': [
      'nagy', 'kis', 'pici', 'óriási', 'apró',
      'pindúr', 'kicsi', 'rövid', 'hosszú', 'ujjnyi',
      'babszem', 'széles', 'dagi', 'vézna', 'chonky',
      'csipetnyi', 'mini', 'giga',
    ],
    'Color': [
      'kék', 'zöld', 'sárga', 'piros', 'bordó',
      'barna', 'fekete', 'fehér', 'lila', 'cián',
      'magenta', 'bézs', 'azúr', 'szürke', 'buszkék',
      'babzöld', 'bilikék', 'cinóber', 'cölinkék', 'deres',
      'drapp', 'fakó', 'falfehér', 'fréz', 'fűzöld',
      'gyíkzöld', 'hússzín', 'kakabarna', 'lázpiros', 'muszlinkék',
      'nedvzöld', 'ordas', 'ősz', 'pej', 'pink',
      'rőt', 'sörszín', 'svédszőke', 'szűzfehér', 'vérvörös',
      'vörös', 'bordó',
    ],
    'State': [
      'rút', 'büdös', 'kedves', 'szagos', 'retkes',
      'hazug', 'nedves', 'hangos', 'koszos', 'szép',
      'közmunkás', 'csóró', 'paraszt', 'zsidó', 'kínai',
      'indiai', 'temus', 'olcsó', 'gagyi', 'fonnyadt',
      'öreg', 'egyenes', 'ferde', 'fura', 'meleg',
      'homokos', 'kiskorú', 'szűz', 'érett', 'transz',
      'szakállas', 'szőrös', 'felizgult', 'tüzelő', 'kanos',
      'veszett', 'fideszes', 'bérenc', 'tiszás', 'KDMP-s',
      'lányos', 'izmos', 'izzadt', 'lucskos', 'olajos',
      'kopasz', 'bolyhos', 'puha', 'érdi', 'pesti',
      'budai', 'győri', 'pécsi', 'aljas', 'nyálas',
      'füves', 'langyi', 'csicska', 'merev', 'szűk',
    ],
  };
  static List<String> get adjectivesAnyEasy =>
      adjectivesMapEasy.values.expand((l) => l).toList();

  static const Map<String, List<String>> adjectivesMapHard = {
    'Size': [
      'eszméletlenül nagy', 'gigantikus', 'incuri-pincuri', 'mikroszkópikus', 'egészen normális méretű',
      'természetellenesen kicsi', 'felettébb széles', 'furcsán hosszú', 'különösen keskeny', 'végtelenül kicsi',
      'száz méteres', 'tíz méteres', 'fél méteres', 'felfoghatatlanul nagy', 'ember méretű',
      'komikusan pinduri', 'röhejesen aprócska',
    ],
    'Color': [
      'körömvirágsárga', 'admiráliskék', 'aranyokker', 'birsalmasárga', 'bogáncsfekete',
      'cigányfekete', 'cigánybarna', 'cigánypiros', 'cigányzöld', 'cukormázrózsaszín',
      'krizantémfehér', 'kukásautó-narancs', 'lámpakorom-fekete', 'makadámdiószín', 'Monarchia-sárga',
      'nikkel-titánsárga', 'paliszanderbarna', 'parasztrózsaszín', 'rhodamine-vörös', 'rózsabogárzöld',
      'sárkányvérvörös', 'skarabeuszzöld', 'skandinávszőke', 'Tóth Menyhért-fehér', 'tökfőzelékszín',
      'tüzes krómoxidzöld', 'vadgalambkék', 'vattacukor-rózsaszín', 'vörösbegytojás-kék', 'kadmiumnarancs',
      'gyöngyvirágfehér', 'gumiguttisárga', 'gesztenyepürészín', 'elefántcsontfekete', 'Coca-Cola-piros',
      'cappuccinobarna', 'brüsszeli sárga', 'borsólevesszín',
    ],
    'State': [
      'akaratképtelen', 'adósságmentes', 'alsó-szászországi', 'antidiszkriminációs', 'anyagtakarékos',
      'bacilushordozó', 'bacilusmentes', 'beszámíthatatlan', 'bőrkeményedéses', 'demokráciaellenes',
      'embergyűlölő', 'energiahatékony', 'félgömb alakú', 'gondolatszegény', 'gőzkibocsátó',
      'határozatképtelen', 'háromdimenziós', 'kacsacsőrű', 'kardiovaszkuláris', 'kibetűzhetetlen',
      'kifürkészhetetlen', 'kereszténydemokrata', 'kormányellenes', 'kormánybarát', 'koldusszegény',
      'kétségbevonhatatlan', 'kábítószerfüggő', 'kábítószer-ellenes', 'kvantummechanikai', 'környezetszennyező',
      'legyengült immunrendszerű', 'makkegészséges', 'manipulálhatatlan', 'Marshall-szigeteki', 'megváltoztathatatlan',
      'második generációs', 'nyomdafestéket nem tűrő', 'omlásveszélyes', 'objektumorientált', 'reményvesztett',
      'sportszerűtlen', 'sebezhetetlen', 'szent és sérthetetlen', 'szigorúan monoton növekvő', 'szociáldemokrata',
      'tengeralattjáró-elhárító', 'tudományos-fantasztikus', 'társadalomátalakító', 'társaságkedvelő', 'transzszexuális',
      'homoszekszuális', 'heteroszekszuális', 'vallásellenes', 'zsidómentes', 'zsidóellenes',
      'zsidóbarát', 'tántoríthatatlan', 'puncipöcögtető', 'utcaiharcos', 'basically street fighter',
      'holokauszt-túlélő', 'dongalábú', 'csempeszobában nevelkedett', 'indiai kenukormányos', 'szőröstalpú',
      'piromániás', 'fejlődésben megrekedt', 'visszamaradott', 'fejben nem százas', 'hatszor tíz a huszonharmadikon',
      'hormonzavaros', 'közalkalmazott', 'gyermekbántalmazó',
      'bungee jumpingoló', 'repülőből kiugró', 'szabadságvesztését töltő',
      'hegyimentő helikopterrel utazó', 'kanapékrumpli', 'színtiszta abszinton élő',
      'krónikus alkoholista', 'ultramagas hőmérsékleten hőkezelt', 'jászalsószentgyörgyi',
      'Péliföldszentkereszten született', 'Szentkirályszabadján iskolába járt', 'Nyugotszenterzsébeten élő',
      'Budapest Pride-on résztvevő', 'negyedfokú égési sérülést szenvedett',
    ],
  };
  static List<String> get adjectivesAnyHard =>
      adjectivesMapHard.values.expand((l) => l).toList();

  static const Map<String, List<String>> objectsMapEasy = {
    'Being': [
      'Lacit', 'Levit', 'Dominikot', 'Dávidot', 'Lalót',
      'Tóbit', 'Botit', 'Ákost', 'Barnust', 'Petikét',
      'Lölőt', 'Vityát', 'Petyát', 'Lázárt', 'Orbánt',
      'Kari Gerit', 'Kriszt', 'Domát', 'Orsit', 'Zsuzsit',
      'Ádámot', 'Ricsit', 'Eriket', 'Tomit', 'anyádat',
      'Pócsot', 'Bibit', 'Ferót', 'Lilut', 'Lilót'
    ],
    'Thing': [
      'rudat', 'dobozt', 'WC-papírt', 'zsepit', 'répát',
      'kutyát', 'macskát', 'lovat', 'tehenet', 'kecskét',
      'medvét', 'hörcsögöt', 'teknőst', 'házat', 'pénzt',
      'tortát', 'játékot', 'egeret', 'gépet', 'poharat',
      'ajtót',
    ],
  };
  static List<String> get objectsAnyEasy =>
      objectsMapEasy.values.expand((l) => l).toList();

  static const Map<String, List<String>> objectsMapHard = {
    'Being': [
      'Szalai Lászlót', 'Erdélyi Dominikot', 'Valaczkai Dávid Márkot', 'Füller Lajost', 'Szűcs Barnabás Olivért',
      'Marozsák Tóbiást', 'Varga Leventét', 'Peőcz Krisztiánt', 'Fekete Botondot', 'Süle Ákost',
      'Radnai Márkot', 'Micimackót', 'Németh Bazsit', 'Karácsony Gerit', 'Márky-Zay Pétert',
      'Orbán Viktort', 'Magyar Petikét', 'Gulyás Gerit', 'Forsthoffer Ágnest', 'Gyurcsány Ferencet',
      'Volodymyr Oleksandrovych Zelenskyy-t', 'Vladimir Vladimirovich Putin-t', 'Vitézy Dávidot', 'Lázár Jánost', 'Thomas a gőzmozdonyt',
      'Xi Jinping-et', 'Ulf Kristersson-t', 'Jeffrey Epsteint', 'Toroczkai Lászlót', 'Horthy Miklóst',
      'Mészáros Lőrincet', 'Guttengéber Lillát',
    ],
    'Thing': [
      'ajtókilincset', 'kvantumszámítógépet', 'lélegeztetőgépet', 'konyhabútort', 'Barbie babát',
      'szalmazsákot', 'ütvefúrót', 'betonkeverőt', 'szülinapi tortát', 'seteményes tálcát',
      'Hulala habalapot', 'pöttyös túrórudit', 'Lázárinfót', 'kormányhatározatot', 'alaptörvénymódosítást',
      'csillagszórót', 'tüzijátékot', 'miniszterelnök urat', 'házelnök asszonyt', 'köztársasági elnök urat',
      'biztonsági zárat', 'szívizomgyulladást', 'városi gettót', 'falusi elitet', 'Nemzeti Együttműködés Rendszerét',
      'Nemzeti Együttbűnözés Rendszerét', 'Nemzeti Alaptantervet', 'katás vállalkozókat', 'Nemzeti Adó- és Vámhivatalt', 'lombkorona nélküli lombkoronasétányt',
      'víz nélküli csónakázótavat', 'sehonnan sehová vezető körforgalmat', 'európai uniós forrásokat', 'Mészáros Lőrinc vagyonát', 'muzsikus cigányt',
      'Csacsi öreg medvét', 'Nemzeti Vagyonvédelmi és Visszaszerzési Hivatalt', 'tízparancsolatot', 'ajándékcsomagot', 'mákos baszkuranciát',
      'óriási kisegeret', 'székelyt meg a fiát', 'etióp esélyegyenlőségi ombudsmant', 'nagy büszke amerikai rétisast', 'ötvenkilós verebet',
      'indukciós főzőlapot', 'bio baobabot', 'keksz ízű Danone görögjoghurtot',
      'munkavállalói értékpapír juttatási program elismert programként történő nyilvántartásba vételére irányuló kérelemnek az állami adóhatóság által rendszeresített nyomtatvány mintáját', 'ocsmány asszonyt', 'bölcs lézert',
      'paksi atomerőművet', 'Duna rekordalacsony vízállását', 'magyar társadalmat', 'iskolai hörcsögöt', 'jókívánságot',
      'kiskorú gyereket', 'legális életkorú fiatalt', 'Munkács várán lévő likat',
      'spanyol inkvizíciót', 'villamosenergia-hálózatot', 'gyerekhálózsákot',
      'Kőbányai szopófantomot', 'páncélozott harcjárművet', 'vajdacigányt',
      'fideszes nyuggert', 'frissen született csecsemőt', 'ausztriai festőt',
      'Mein Kampf-ot', 'cigányasszonyt', 'kakaós miafaszomat',
      'atommeghajtású tengeralattjárót',
    ],
  };
  static List<String> get objectsAnyHard =>
      objectsMapHard.values.expand((l) => l).toList();

  static const List<String> sentenceStructuresEasy = [
    '{subject} {verb} {article} {objectAny}.',
    '{subject} {verb} {article} {adjectiveAny} {objectThing}.',
    'Ha {subject} {verb}, {subject} is {verb}.',
    '{subject} nem {verb} {article} {objectThing}.',
    'Tudtad, hogy {subject} {verb} {article} {objectAny}?',
    '{subject} hirtelen {verb} {article} {objectAny}.',
    'Szerintem {subject} {verb} {article} {adjectiveState} {objectAny}.',
    'Biztos, hogy {subject} {verb} {article} {objectAny}?',
    'Amikor {subject} {verb}, {subject} {verb}.',
    '{subject} és {subject} {verb} {article} {objectAny}.',
    'Vajon {subject} {verb} {article} {adjectiveAny} {objectThing}?',
    'Néha {subject} {verb} {article} {adjectiveAny} {objectBeing}.',
    '{verb} mint {adjectiveState} {subject} {article} {objectAny}.',
  ];

  static const List<String> sentenceStructuresHard = [
    '{subject} {verb} {article} {adjectiveState} {adjectiveColor} {objectThing}, mire {subject} {verb} {objectBeing}.',
    '{subject} {verb} {article} {adjectiveState} {adjectiveColor} {objectThing}, majd {subject} ugyancsak {verb} {article} {adjectiveAny} {objectBeing}.',
    '{subject} és {article} {subject} {verb} {article} {adjectiveState}, {adjectiveSize}, {adjectiveColor} {objectAny}.',
    '{article} {adjectiveSize} {subject} néhanapján {verb} {article} {objectThing}.',
    'Egyszer majd {article} {adjectiveState} {subject} is {verb} {article} {adjectiveAny} {objectAny}!',
    'Biztos, hogy {subject} {verb} {article} {adjectiveSize} {adjectiveColor} {objectAny}?',
    '{subject} tényleg {verb} {article} {adjectiveSize} {adjectiveColor} {objectAny}, vagy csak {verb}?',
    '{subject} tényleg {adjectiveColor}, vagy inkább {adjectiveColor}, netán {adjectiveColor}?',
    'Elképzelhető, ahogy {subject} {verb} {article} {adjectiveSize}, {adjectiveState}, {adjectiveColor} {objectAny}.',
    'Tudtad, hogy {subject} gyakran {verb} {article} {adjectiveAny} {objectAny}, nem úgy mint {article} {adjectiveSize} {subject}?',
    'Ha {subject} {verb} {article} {objectThing}, akkor {subject} biztosan {verb} {article} {adjectiveAny} {objectBeing}.',
    'Szerintem {subject} nem {verb} {article} {adjectiveSize} {objectThing}, hanem inkább {verb} {article} {adjectiveColor} {objectAny}.',
    'Képzeld el, ahogy {subject} hirtelen {verb} {article} {adjectiveState} {objectAny}!',
    'Vajon majd ha egyszer {subject} {verb} {article} {adjectiveColor} {objectThing}, elképzelhető hogy {subject} is {verb} {article} {objectThing}?',
    'Míg {subject} {verb}, addig {subject} {verb} {article} {adjectiveSize} {objectAny}.',
    'Nem hiszem el, hogy {article} {adjectiveState} {subject} {verb} {article} {adjectiveColor} {objectAny}!',
    'Talán {subject} nem is {verb}, csak {verb} {article} {adjectiveAny} {objectThing}.',
    'Ahogy {subject} {verb}, úgy {subject} is {verb} {article} {adjectiveSize} {objectAny}.',
    'Lehet, hogy {subject} {verb} {article} {adjectiveState} {objectBeing}, de {subject} inkább {verb}.',
    'Rendkívül {adjectiveState} lesz, amikor majd {subject} {verb} {article} {adjectiveColor} {objectAny}.',
    'Kétségtelen, hogy {subject} {verb} {article} {adjectiveSize}, {adjectiveColor} {objectThing}.',
    'Bár {subject} {verb} {article} {objectThing}, {subject} továbbra is {verb} {article} {objectBeing}.',
    'Valójában {subject} nem {verb}, csak {verb} {article} {adjectiveAny} {objectAny}.',
    'Micsoda {adjectiveSize} meglepetés lesz majd az, ahogy {subject} {verb} {article} {adjectiveColor} {objectThing}!',
    'Gyakran megesik, hogy {subject} {verb} {article} {adjectiveSize} {objectBeing}.',
    'Tudtad, hogy {subject} holnap {verb} {article} {adjectiveState} {objectAny}?',
    'Mindenki tudja, hogy {subject} {verb} {article} {adjectiveColor} {objectThing}, és {verb} {article} {adjectiveAny} {objectBeing}.',
    'Kizárt dolog, hogy {subject} {verb} {article} {adjectiveSize} {objectAny}, de azért nem lehetetlen.',
    'Csak, ha {subject} {verb} {article} {adjectiveColor}, {adjectiveSize} {objectThing}, máskülönben szó sem lehet róla!',
    'Amikor {subject} {verb} {article} {adjectiveState} {objectAny}, {subject} nyomban {verb} {article} {adjectiveColor} {objectThing}.',
    'Általában {subject} el {verb}, {adjectiveState} {objectAny}, {subject} nyomban {verb} {article} {adjectiveColor} {objectThing}.',
  ];

  static List<String> generateText(
    int sentenceCount,
    bool useEasyWords,
    math.Random random,
  ) {
    List<String> sentences = [];

    final currentSubjects = (useEasyWords ? subjectsEasy : subjectsHard)
        .where((s) => s.isNotEmpty)
        .toList();
    final currentVerbs = (useEasyWords ? verbsEasy : verbsHard)
        .where((s) => s.isNotEmpty)
        .toList();
    final currentAdjectivesMap = useEasyWords
        ? adjectivesMapEasy
        : adjectivesMapHard;
    final currentAdjectivesAny = useEasyWords
        ? adjectivesAnyEasy
        : adjectivesAnyHard;
    final currentObjectsMap = useEasyWords ? objectsMapEasy : objectsMapHard;
    final currentObjectsAny = useEasyWords ? objectsAnyEasy : objectsAnyHard;

    final currentStructures = useEasyWords
        ? sentenceStructuresEasy
        : sentenceStructuresHard;

    Set<String> usedWords = {};
    String pickWord(List<String> pool) {
      var available = pool.where((w) => !usedWords.contains(w)).toList();
      if (available.isEmpty) available = pool; // Fallback if pool is exhausted
      String word = available[random.nextInt(available.length)];
      usedWords.add(word);
      return word;
    }

    Set<String> usedStructures = {};
    String pickStructure() {
      var available = currentStructures
          .where((s) => !usedStructures.contains(s))
          .toList();
      if (available.isEmpty) available = currentStructures; // Fallback
      String structure = available[random.nextInt(available.length)];
      usedStructures.add(structure);
      return structure;
    }

    for (int i = 0; i < sentenceCount; i++) {
      String structure = pickStructure();

      String sentence = structure
          .replaceAllMapped('{subject}', (_) => pickWord(currentSubjects))
          .replaceAllMapped('{verb}', (_) => pickWord(currentVerbs));

      // Dynamically replace all {adjective...} and {object...} placeholders
      sentence = sentence.replaceAllMapped(
        RegExp(r'\{(adjective|object)([A-Za-z]*)\}'),
        (match) {
          String type = match.group(1)!;
          String subcategory = match.group(2)!;

          List<String> pool;
          if (type == 'adjective') {
            if (subcategory == 'Any' || subcategory.isEmpty) {
              pool = currentAdjectivesAny;
            } else {
              pool = currentAdjectivesMap[subcategory] ?? currentAdjectivesAny;
            }
          } else {
            if (subcategory == 'Any' || subcategory.isEmpty) {
              pool = currentObjectsAny;
            } else {
              pool = currentObjectsMap[subcategory] ?? currentObjectsAny;
            }
          }
          pool = pool.where((s) => s.isNotEmpty).toList();

          return pickWord(pool);
        },
      );

      // Resolve {article} dynamically ("a" or "an" depending on next letter)
      // Note: for Hungarian, this logic can easily be swapped to "A" or "Az"
      while (sentence.contains('{article}')) {
        int idx = sentence.indexOf('{article}');
        // Find the first letter of the following word (skip spaces)
        int nextCharIdx = idx + '{article}'.length;
        while (nextCharIdx < sentence.length && sentence[nextCharIdx] == ' ') {
          nextCharIdx++;
        }

        String articleToUse = 'a';
        if (nextCharIdx < sentence.length) {
          String nextChar = sentence[nextCharIdx].toLowerCase();
          if ([
            'a',
            'e',
            'i',
            'o',
            'u',
            'á',
            'é',
            'í',
            'ü',
            'ö',
            'ő',
            'ű',
          ].contains(nextChar)) {
            articleToUse = 'az';
          }
        }

        sentence = sentence.replaceFirst('{article}', articleToUse);
      }

      // Cleanup multiple spaces that might occur if an article is empty
      sentence = sentence.replaceAll(RegExp(r'\s+'), ' ').trim();

      // Ensure first letter is capitalized
      if (sentence.isNotEmpty) {
        sentence = sentence[0].toUpperCase() + sentence.substring(1);
      }
      sentences.add(sentence);
    }
    return sentences;
  }

  const SpeedTypingConfig() : super(icon: Icons.text_fields);
}
