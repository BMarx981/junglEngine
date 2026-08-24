// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Haitian Haitian Creole (`ht`).
class AppLocalizationsHt extends AppLocalizations {
  AppLocalizationsHt([String locale = 'ht']) : super(locale);

  @override
  String get appTitle => 'junglEngine';

  @override
  String barCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count MEZI',
      one: '1 MEZI',
    );
    return '$_temp0';
  }

  @override
  String barCountSentence(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mezi',
      one: '1 mezi',
    );
    return '$_temp0';
  }

  @override
  String barUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'MEZI',
      one: 'MEZI',
    );
    return '$_temp0';
  }

  @override
  String cardCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count KAT',
      one: '1 KAT',
    );
    return '$_temp0';
  }

  @override
  String beatLabel(String name) {
    return 'BEAT $name';
  }

  @override
  String get studioLoadingBreak => 'Y AP CHAJE BREAK LA';

  @override
  String get studioEngineFailed => 'MOTÈ ODYO A PA MACHE';

  @override
  String get transportClear => 'EFASE';

  @override
  String get transportArrangement => 'RANJMAN';

  @override
  String get barStripLabel => 'MEZI';

  @override
  String actionAddBeat(String name) {
    return 'AJOUTE $name';
  }

  @override
  String get actionScramble => 'MELANJE';

  @override
  String get actionUndo => 'DEFÈ';

  @override
  String get actionExport => 'EKSPÒTE';

  @override
  String get beatBarSong => 'CHANSON';

  @override
  String get beatBarGrid => 'KADRIYAJ';

  @override
  String get beatBarDup => 'KOPI';

  @override
  String get beatBarNew => 'NÒUVO';

  @override
  String get beatBarDelete => 'EFASE BEAT LA';

  @override
  String get newBeatTitle => 'NOUVO BEAT';

  @override
  String get newBeatMachine => 'MACHIN';

  @override
  String get newBeatChopDetail => 'RANJE BREAK LA ANKÒ';

  @override
  String get newBeatKitDetail => 'UIT ONE SHOT';

  @override
  String get newBeatLength => 'LONGÈ';

  @override
  String get newBeatCreate => 'KREYE';

  @override
  String get songTitle => 'CHANSON';

  @override
  String get songEmpty =>
      'PA GEN ANYEN RANJE ANKÒ\n\nAJOUTE BEAT KI LOUVRI A DEPI BAR ANBA A, EPI CHWAZI KONBYEN FWA POU L REPETE';

  @override
  String get libraryBreak => 'BREAK';

  @override
  String get libraryYours => 'PA W';

  @override
  String get libraryImportFirst => 'ENPÒTE PA W';

  @override
  String get libraryImportAnother => 'ENPÒTE YON LÒT';

  @override
  String get libraryNote =>
      'YON SÈL BREAK AK YON SÈL KIT PA PWOJÈ. CHANJE BREAK LA PA EFASE MODÈL OU YO.';

  @override
  String get exportTitleWav => 'EKSPÒTE WAV';

  @override
  String get exportTitleParts => 'EKSPÒTE PYÈS YO';

  @override
  String get exportModeLoop => 'LOOP';

  @override
  String get exportModeSong => 'CHANSON';

  @override
  String get exportModeParts => 'PYÈS';

  @override
  String get exportMidiSlices => 'MIDI + SLICES';

  @override
  String get exportNothingArranged => 'ANYEN RANJE';

  @override
  String get exportRepeats => 'REPETISYON';

  @override
  String get exportRender => 'FÈ L EPI PATAJE';

  @override
  String get exportBuild => 'BATI EPI PATAJE';

  @override
  String exportSongDetail(String bars, int bpm) {
    return 'Tout ranjman an, $bars nan $bpm BPM, 44.1 kHz 16 bit';
  }

  @override
  String exportLoopDetail(String bars, int bpm) {
    return '$bars nan $bpm BPM, 44.1 kHz 16 bit';
  }

  @override
  String exportPartsDetail(String name, String content, int note) {
    return 'Beat $name kòm yon fichye MIDI ak $content l ap jwe a, plase depi nòt $note pou Kong ak NN-XT';
  }

  @override
  String get exportPartsKit => 'kit la';

  @override
  String get exportPartsSlices => 'slices yo';

  @override
  String get exportFailed => 'Ekspòtasyon an pa mache';

  @override
  String stepModStep(int number) {
    return 'PA $number';
  }

  @override
  String get stepModEmpty => 'VID';

  @override
  String get stepModPlain => 'SENP';

  @override
  String get stepModReverse => 'ALANVÈ';

  @override
  String get stepModRetrig => 'REPETE';

  @override
  String get stepModPitchDown => 'TON PI BA';

  @override
  String get stepModHalfSpeed => 'MWATYE VIT';

  @override
  String get kitHint => 'KENBE YON PAD POU VOL AK PITCH';

  @override
  String kitSlot(int number) {
    return 'PLAS $number';
  }

  @override
  String get kitImportOneShot => 'ENPÒTE ONE SHOT';

  @override
  String get kitImportOneShotPro => 'ENPÒTE ONE SHOT  (PRO)';

  @override
  String get kitReplace => 'RANPLASE';

  @override
  String get kitUseKitSample => 'SÈVI AK SAMPLE KIT LA';

  @override
  String get subTitle => 'SUB SENTE';

  @override
  String get subClearLane => 'EFASE LIY LAN';

  @override
  String get subHint => 'RALE PITCH KENBE AKSAN';

  @override
  String get subEdit => 'MODIFYE NÒT YO';

  @override
  String get subNotesTitle => 'NÒT SUB';

  @override
  String get subEditorHint => 'TOUCHE YON KAZ POU METE YON NÒT';

  @override
  String get subAccent => 'AKSAN';

  @override
  String get subClearNote => 'EFASE NÒT LA';

  @override
  String get subMoveEarlier => 'DEPLASE NÒT LA YON PA PI BONÈ';

  @override
  String get subMoveLater => 'DEPLASE NÒT LA YON PA PI TA';

  @override
  String get importTitle => 'ENPÒTE BREAK';

  @override
  String get importBars => 'MEZI';

  @override
  String get importTempo => 'TEMPO';

  @override
  String get importPreviewLoop => 'TANDE LOOP LA';

  @override
  String get importStop => 'KANPE';

  @override
  String get importTap => 'TAP';

  @override
  String importTapCount(int count) {
    return 'TAP $count';
  }

  @override
  String get importUseBreak => 'SÈVI AK BREAK SA A';

  @override
  String importTooFast(int bpm, String bars) {
    return 'SA FÈ $bpm BPM AK $bars. ESEYE YON LÒT KANTITE MEZI.';
  }

  @override
  String get importTruncated =>
      'FICHYE SA A TE PI LONG PASE LIMIT LA EPI YO KOUPE L.';

  @override
  String get importFailed => 'Enpòtasyon an pa mache';

  @override
  String get importErrorPicker => 'Nou pa t kapab louvri chwazisè fichye a.';

  @override
  String get importErrorDecode => 'Fichye sa a pa t ka dekode.';

  @override
  String get importErrorTooShort => 'Fichye sa a twò kout pou koupe.';

  @override
  String get proTitle => 'JUNGLENGINE PRO';

  @override
  String get proTagline => 'YON SÈL ACHA. PA GEN ABÒNMAN. PA GEN PIBLISITE.';

  @override
  String get proFreeHeader => 'GRATIS DEJA, EPI L AP RETE GRATIS';

  @override
  String get proRestore => 'REKIPERE ACHA A';

  @override
  String get proDebugUnlock => 'DEBUG: DEBLOKE SAN ACHTE';

  @override
  String get proHavePro => 'OU GEN PRO';

  @override
  String get proWaiting => 'N AP TANN MAGAZEN AN';

  @override
  String get proChecking => 'N AP TCHEKE';

  @override
  String get proUnavailableNow => 'PA DISPONIB KOUNYE A';

  @override
  String proGet(String price) {
    return 'PRAN PRO  $price';
  }

  @override
  String get proPurchasesOff => 'ACHA YO FÈMEN SOU APARÈY SA A';

  @override
  String get proPurchaseFailed => 'Acha a pa t pase.';

  @override
  String get proFeatureImportTitle => 'ENPÒTE PWÒP ODYO PA W';

  @override
  String get proFeatureImportDetail =>
      'Nenpòt break, nenpòt one shot, depi Files, iCloud, Drive oswa yon mesaj. Koupe l, tape tempo a, chope l.';

  @override
  String get proFeatureMidiTitle => 'EKSPÒTE MIDI AK SLICES';

  @override
  String get proFeatureMidiDetail =>
      'Beat la kòm yon fichye MIDI ak sample l ap jwe yo, plase pou yo tonbe dirèk nan Kong oswa NN-XT.';

  @override
  String get proFeaturePacksTitle => 'PAKÈ SLICES';

  @override
  String get proFeaturePacksDetail =>
      'Break ak kit fèt pou sa a, dapre jan yo soti.';

  @override
  String get proFreeBundled => 'Tout break ak kit ki enkli yo';

  @override
  String get proFreeMachines => 'De machin yo, tout kadriyaj la, liy sub la';

  @override
  String get proFreeSongs => 'Chanson ak ekspòtasyon WAV';

  @override
  String get proFreeNoAds => 'Pa gen piblisite, jamè';
}
