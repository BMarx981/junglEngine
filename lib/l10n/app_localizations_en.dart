// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'junglEngine';

  @override
  String barCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count BARS',
      one: '1 BAR',
    );
    return '$_temp0';
  }

  @override
  String barCountSentence(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bars',
      one: '1 bar',
    );
    return '$_temp0';
  }

  @override
  String barUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'BARS',
      one: 'BAR',
    );
    return '$_temp0';
  }

  @override
  String cardCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count CARDS',
      one: '1 CARD',
    );
    return '$_temp0';
  }

  @override
  String beatLabel(String name) {
    return 'BEAT $name';
  }

  @override
  String get studioLoadingBreak => 'LOADING BREAK';

  @override
  String get studioEngineFailed => 'AUDIO ENGINE FAILED';

  @override
  String get transportClear => 'CLEAR';

  @override
  String get transportArrangement => 'ARRANGEMENT';

  @override
  String get barStripLabel => 'BAR';

  @override
  String actionAddBeat(String name) {
    return 'ADD $name';
  }

  @override
  String get actionScramble => 'SCRAMBLE';

  @override
  String get actionUndo => 'UNDO';

  @override
  String get actionExport => 'EXPORT';

  @override
  String get beatBarSong => 'SONG';

  @override
  String get beatBarGrid => 'GRID';

  @override
  String get beatBarDup => 'DUP';

  @override
  String get beatBarNew => 'NEW';

  @override
  String get beatBarDelete => 'DELETE BEAT';

  @override
  String get newBeatTitle => 'NEW BEAT';

  @override
  String get newBeatMachine => 'MACHINE';

  @override
  String get newBeatChopDetail => 'RESEQUENCE THE BREAK';

  @override
  String get newBeatKitDetail => 'EIGHT ONE SHOTS';

  @override
  String get newBeatLength => 'LENGTH';

  @override
  String get newBeatCreate => 'CREATE';

  @override
  String get songTitle => 'SONG';

  @override
  String get songEmpty =>
      'NOTHING ARRANGED YET\n\nADD THE BEAT YOU HAVE OPEN FROM THE BAR BELOW, THEN SET HOW MANY TIMES IT REPEATS';

  @override
  String get libraryBreak => 'BREAK';

  @override
  String get libraryYours => 'YOURS';

  @override
  String get libraryImportFirst => 'IMPORT YOUR OWN';

  @override
  String get libraryImportAnother => 'IMPORT ANOTHER';

  @override
  String get libraryNote =>
      'ONE BREAK AND ONE KIT PER PROJECT. CHANGING THE BREAK KEEPS YOUR PATTERNS.';

  @override
  String get exportTitleWav => 'EXPORT WAV';

  @override
  String get exportTitleParts => 'EXPORT PARTS';

  @override
  String get exportModeLoop => 'LOOP';

  @override
  String get exportModeSong => 'SONG';

  @override
  String get exportModeParts => 'PARTS';

  @override
  String get exportMidiSlices => 'MIDI + SLICES';

  @override
  String get exportNothingArranged => 'NOTHING ARRANGED';

  @override
  String get exportRepeats => 'REPEATS';

  @override
  String get exportRender => 'RENDER AND SHARE';

  @override
  String get exportBuild => 'BUILD AND SHARE';

  @override
  String exportSongDetail(String bars, int bpm) {
    return 'The whole arrangement, $bars at $bpm BPM, 44.1 kHz 16 bit';
  }

  @override
  String exportLoopDetail(String bars, int bpm) {
    return '$bars at $bpm BPM, 44.1 kHz 16 bit';
  }

  @override
  String exportPartsDetail(String name, String content, int note) {
    return 'Beat $name as a MIDI file and the $content it plays, mapped from note $note for Kong and NN-XT';
  }

  @override
  String get exportPartsKit => 'kit';

  @override
  String get exportPartsSlices => 'slices';

  @override
  String get exportFailed => 'Export failed';

  @override
  String stepModStep(int number) {
    return 'STEP $number';
  }

  @override
  String get stepModEmpty => 'EMPTY';

  @override
  String get stepModPlain => 'PLAIN';

  @override
  String get stepModReverse => 'REVERSE';

  @override
  String get stepModRetrig => 'RETRIG';

  @override
  String get stepModPitchDown => 'PITCH DOWN';

  @override
  String get stepModHalfSpeed => 'HALF SPEED';

  @override
  String get kitHint => 'HOLD A PAD FOR VOL AND PITCH';

  @override
  String kitSlot(int number) {
    return 'SLOT $number';
  }

  @override
  String get kitImportOneShot => 'IMPORT ONE SHOT';

  @override
  String get kitImportOneShotPro => 'IMPORT ONE SHOT  (PRO)';

  @override
  String get kitReplace => 'REPLACE';

  @override
  String get kitUseKitSample => 'USE KIT SAMPLE';

  @override
  String get subTitle => 'SUB SYNTH';

  @override
  String get subClearLane => 'CLEAR LANE';

  @override
  String get subHint => 'DRAG PITCH HOLD ACCENT';

  @override
  String get subEdit => 'EDIT NOTES';

  @override
  String get subNotesTitle => 'SUB NOTES';

  @override
  String get subEditorHint => 'TAP A CELL TO PLACE A NOTE';

  @override
  String get subAccent => 'ACCENT';

  @override
  String get subClearNote => 'CLEAR NOTE';

  @override
  String get subMoveEarlier => 'MOVE EARLIER';

  @override
  String get subMoveLater => 'MOVE LATER';

  @override
  String get importTitle => 'IMPORT BREAK';

  @override
  String get importBars => 'BARS';

  @override
  String get importTempo => 'TEMPO';

  @override
  String get importPreviewLoop => 'PREVIEW LOOP';

  @override
  String get importStop => 'STOP';

  @override
  String get importTap => 'TAP';

  @override
  String importTapCount(int count) {
    return 'TAP $count';
  }

  @override
  String get importUseBreak => 'USE THIS BREAK';

  @override
  String importTooFast(int bpm, String bars) {
    return 'THAT IS $bpm BPM AT $bars. TRY A DIFFERENT BAR COUNT.';
  }

  @override
  String get importTruncated =>
      'THAT FILE WAS LONGER THAN THE IMPORT LIMIT AND WAS CUT SHORT.';

  @override
  String get importFailed => 'Import failed';

  @override
  String get importErrorPicker => 'Could not open the file picker.';

  @override
  String get importErrorDecode => 'That file would not decode.';

  @override
  String get importErrorTooShort => 'That file is too short to chop.';

  @override
  String get proTitle => 'JUNGLENGINE PRO';

  @override
  String get proTagline => 'ONE PURCHASE. NO SUBSCRIPTION. NO ADS.';

  @override
  String get proFreeHeader => 'ALREADY FREE, AND STAYING FREE';

  @override
  String get proRestore => 'RESTORE PURCHASE';

  @override
  String get proDebugUnlock => 'DEBUG: UNLOCK WITHOUT BUYING';

  @override
  String get proHavePro => 'YOU HAVE PRO';

  @override
  String get proWaiting => 'WAITING FOR THE STORE';

  @override
  String get proChecking => 'CHECKING';

  @override
  String get proUnavailableNow => 'NOT AVAILABLE RIGHT NOW';

  @override
  String proGet(String price) {
    return 'GET PRO  $price';
  }

  @override
  String get proPurchasesOff => 'PURCHASES ARE OFF ON THIS DEVICE';

  @override
  String get proPurchaseFailed => 'The purchase did not go through.';

  @override
  String get proFeatureImportTitle => 'IMPORT YOUR OWN AUDIO';

  @override
  String get proFeatureImportDetail =>
      'Any break, any one shot, from Files, iCloud, Drive or a message. Trim it, tap the tempo, chop it.';

  @override
  String get proFeatureMidiTitle => 'MIDI AND SLICES EXPORT';

  @override
  String get proFeatureMidiDetail =>
      'The beat as a MIDI file and the samples it plays, mapped to drop straight into Kong or NN-XT.';

  @override
  String get proFeaturePacksTitle => 'SLICE PACKS';

  @override
  String get proFeaturePacksDetail =>
      'Breaks and kits made for this, as they land.';

  @override
  String get proFreeBundled => 'Every bundled break and kit';

  @override
  String get proFreeMachines => 'Both machines, the whole grid, the sub lane';

  @override
  String get proFreeSongs => 'Songs and WAV export';

  @override
  String get proFreeNoAds => 'No ads, ever';
}
