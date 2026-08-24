// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Filipino Pilipino (`fil`).
class AppLocalizationsFil extends AppLocalizations {
  AppLocalizationsFil([String locale = 'fil']) : super(locale);

  @override
  String get appTitle => 'junglEngine';

  @override
  String barCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count BAR',
      one: '1 BAR',
    );
    return '$_temp0';
  }

  @override
  String barCountSentence(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bar',
      one: '1 bar',
    );
    return '$_temp0';
  }

  @override
  String barUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'BAR',
      one: 'BAR',
    );
    return '$_temp0';
  }

  @override
  String cardCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count CARD',
      one: '1 CARD',
    );
    return '$_temp0';
  }

  @override
  String beatLabel(String name) {
    return 'BEAT $name';
  }

  @override
  String get studioLoadingBreak => 'NILO-LOAD ANG BREAK';

  @override
  String get studioEngineFailed => 'NABIGO ANG AUDIO ENGINE';

  @override
  String get transportClear => 'BURAHIN';

  @override
  String get transportArrangement => 'AYOS';

  @override
  String get barStripLabel => 'BAR';

  @override
  String actionAddBeat(String name) {
    return 'IDAGDAG $name';
  }

  @override
  String get actionScramble => 'HALUIN';

  @override
  String get actionUndo => 'IBALIK';

  @override
  String get actionExport => 'I-EXPORT';

  @override
  String get beatBarSong => 'KANTA';

  @override
  String get beatBarGrid => 'GRID';

  @override
  String get beatBarDup => 'DUP';

  @override
  String get beatBarNew => 'BAGO';

  @override
  String get beatBarDelete => 'BURAHIN ANG BEAT';

  @override
  String get newBeatTitle => 'BAGONG BEAT';

  @override
  String get newBeatMachine => 'MAKINA';

  @override
  String get newBeatChopDetail => 'AYUSIN ULIT ANG BREAK';

  @override
  String get newBeatKitDetail => 'WALONG ONE SHOT';

  @override
  String get newBeatLength => 'HABA';

  @override
  String get newBeatCreate => 'GAWIN';

  @override
  String get songTitle => 'KANTA';

  @override
  String get songEmpty =>
      'WALA PA RITONG NAKAAYOS\n\nIDAGDAG ANG BUKAS NA BEAT MULA SA BAR SA IBABA, TAPOS PILIIN KUNG ILANG ULIT ITO UULITIN';

  @override
  String get libraryBreak => 'BREAK';

  @override
  String get libraryYours => 'IYO';

  @override
  String get libraryImportFirst => 'MAG-IMPORT NG IYO';

  @override
  String get libraryImportAnother => 'MAG-IMPORT NG IBA';

  @override
  String get libraryNote =>
      'ISANG BREAK AT ISANG KIT KADA PROYEKTO. HINDI MAWAWALA ANG MGA PATTERN MO KAPAG PINALITAN ANG BREAK.';

  @override
  String get exportTitleWav => 'I-EXPORT NA WAV';

  @override
  String get exportTitleParts => 'I-EXPORT ANG MGA PARTE';

  @override
  String get exportModeLoop => 'LOOP';

  @override
  String get exportModeSong => 'KANTA';

  @override
  String get exportModeParts => 'PARTE';

  @override
  String get exportMidiSlices => 'MIDI + SLICES';

  @override
  String get exportNothingArranged => 'WALANG NAKAAYOS';

  @override
  String get exportRepeats => 'ULIT';

  @override
  String get exportRender => 'I-RENDER AT IBAHAGI';

  @override
  String get exportBuild => 'BUUIN AT IBAHAGI';

  @override
  String exportSongDetail(String bars, int bpm) {
    return 'Buong ayos, $bars sa $bpm BPM, 44.1 kHz 16 bit';
  }

  @override
  String exportLoopDetail(String bars, int bpm) {
    return '$bars sa $bpm BPM, 44.1 kHz 16 bit';
  }

  @override
  String exportPartsDetail(String name, String content, int note) {
    return 'Ang beat $name bilang MIDI file kasama $content na tinutugtog nito, naka-map mula sa note $note para sa Kong at NN-XT';
  }

  @override
  String get exportPartsKit => 'ang kit';

  @override
  String get exportPartsSlices => 'ang mga slice';

  @override
  String get exportFailed => 'Nabigo ang pag-export';

  @override
  String stepModStep(int number) {
    return 'STEP $number';
  }

  @override
  String get stepModEmpty => 'WALA';

  @override
  String get stepModPlain => 'PLAIN';

  @override
  String get stepModReverse => 'BALIKTAD';

  @override
  String get stepModRetrig => 'ULIT-ULIT';

  @override
  String get stepModPitchDown => 'BABA ANG PITCH';

  @override
  String get stepModHalfSpeed => 'KALAHATING BILIS';

  @override
  String get kitHint => 'PINDUTIN NANG MATAGAL ANG PAD PARA SA VOL AT PITCH';

  @override
  String kitSlot(int number) {
    return 'SLOT $number';
  }

  @override
  String get kitImportOneShot => 'MAG-IMPORT NG ONE SHOT';

  @override
  String get kitImportOneShotPro => 'MAG-IMPORT NG ONE SHOT  (PRO)';

  @override
  String get kitReplace => 'PALITAN';

  @override
  String get kitUseKitSample => 'GAMITIN ANG SAMPLE NG KIT';

  @override
  String get subTitle => 'SUB SYNTH';

  @override
  String get subClearLane => 'LINISIN ANG LANE';

  @override
  String get subHint => 'I-DRAG ANG PITCH PINDUTIN PARA SA ACCENT';

  @override
  String get subEdit => 'I-EDIT ANG MGA NOTA';

  @override
  String get subNotesTitle => 'MGA SUB NOTA';

  @override
  String get subEditorHint => 'PINDUTIN ANG KAHON PARA MAGLAGAY NG NOTA';

  @override
  String get subAccent => 'ACCENT';

  @override
  String get subClearNote => 'BURAHIN ANG NOTA';

  @override
  String get subMoveEarlier => 'IUSOG ANG NOTA NANG ISANG STEP PAAGA';

  @override
  String get subMoveLater => 'IUSOG ANG NOTA NANG ISANG STEP PAHULI';

  @override
  String get importTitle => 'MAG-IMPORT NG BREAK';

  @override
  String get importBars => 'BAR';

  @override
  String get importTempo => 'TEMPO';

  @override
  String get importPreviewLoop => 'PAKINGGAN ANG LOOP';

  @override
  String get importStop => 'TIGIL';

  @override
  String get importTap => 'TAP';

  @override
  String importTapCount(int count) {
    return 'TAP $count';
  }

  @override
  String get importUseBreak => 'GAMITIN ANG BREAK NA ITO';

  @override
  String importTooFast(int bpm, String bars) {
    return '$bpm BPM IYAN SA $bars. SUBUKAN ANG IBANG BILANG NG BAR.';
  }

  @override
  String get importTruncated =>
      'MAS MAHABA ANG FILE NA IYAN SA LIMITE NG IMPORT KAYA PINUTOL ITO.';

  @override
  String get importFailed => 'Nabigo ang pag-import';

  @override
  String get importErrorPicker => 'Hindi mabuksan ang file picker.';

  @override
  String get importErrorDecode => 'Hindi ma-decode ang file na iyan.';

  @override
  String get importErrorTooShort =>
      'Masyadong maikli ang file na iyan para hiwain.';

  @override
  String get proTitle => 'JUNGLENGINE PRO';

  @override
  String get proTagline => 'ISANG BAYAD LANG. WALANG SUBSCRIPTION. WALANG ADS.';

  @override
  String get proFreeHeader => 'LIBRE NA, AT MANANATILING LIBRE';

  @override
  String get proRestore => 'IBALIK ANG PAGBILI';

  @override
  String get proDebugUnlock => 'DEBUG: I-UNLOCK NANG WALANG BAYAD';

  @override
  String get proHavePro => 'MERON KA NANG PRO';

  @override
  String get proWaiting => 'HINIHINTAY ANG STORE';

  @override
  String get proChecking => 'TINITINGNAN';

  @override
  String get proUnavailableNow => 'HINDI AVAILABLE NGAYON';

  @override
  String proGet(String price) {
    return 'KUNIN ANG PRO  $price';
  }

  @override
  String get proPurchasesOff => 'NAKA-OFF ANG MGA PAGBILI SA DEVICE NA ITO';

  @override
  String get proPurchaseFailed => 'Hindi natuloy ang pagbili.';

  @override
  String get proFeatureImportTitle => 'MAG-IMPORT NG SARILING AUDIO';

  @override
  String get proFeatureImportDetail =>
      'Kahit anong break, kahit anong one shot, mula sa Files, iCloud, Drive o mensahe. I-trim, i-tap ang tempo, hiwain.';

  @override
  String get proFeatureMidiTitle => 'MIDI AT SLICES EXPORT';

  @override
  String get proFeatureMidiDetail =>
      'Ang beat bilang MIDI file at ang mga sample na tinutugtog nito, naka-map para diretsong pumasok sa Kong o NN-XT.';

  @override
  String get proFeaturePacksTitle => 'SLICE PACKS';

  @override
  String get proFeaturePacksDetail =>
      'Mga break at kit na gawa para dito, habang lumalabas.';

  @override
  String get proFreeBundled => 'Lahat ng kasamang break at kit';

  @override
  String get proFreeMachines => 'Parehong makina, buong grid, ang sub lane';

  @override
  String get proFreeSongs => 'Mga kanta at WAV export';

  @override
  String get proFreeNoAds => 'Walang ads, kailanman';
}
