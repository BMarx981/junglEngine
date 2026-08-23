// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'junglEngine';

  @override
  String barCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count MESURES',
      one: '1 MESURE',
    );
    return '$_temp0';
  }

  @override
  String barCountSentence(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mesures',
      one: '1 mesure',
    );
    return '$_temp0';
  }

  @override
  String barUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'MESURES',
      one: 'MESURE',
    );
    return '$_temp0';
  }

  @override
  String cardCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count CARTES',
      one: '1 CARTE',
    );
    return '$_temp0';
  }

  @override
  String beatLabel(String name) {
    return 'BEAT $name';
  }

  @override
  String get studioLoadingBreak => 'CHARGEMENT DU BREAK';

  @override
  String get studioEngineFailed => 'ÉCHEC DU MOTEUR AUDIO';

  @override
  String get transportClear => 'EFFACER';

  @override
  String get transportArrangement => 'ARRANGEMENT';

  @override
  String get barStripLabel => 'MES';

  @override
  String actionAddBeat(String name) {
    return 'AJOUTER $name';
  }

  @override
  String get actionScramble => 'MÉLANGER';

  @override
  String get actionUndo => 'ANNULER';

  @override
  String get actionExport => 'EXPORTER';

  @override
  String get beatBarSong => 'MORCEAU';

  @override
  String get beatBarGrid => 'GRILLE';

  @override
  String get beatBarDup => 'DUP';

  @override
  String get beatBarNew => 'NOUV';

  @override
  String get beatBarDelete => 'SUPPRIMER LE BEAT';

  @override
  String get newBeatTitle => 'NOUVEAU BEAT';

  @override
  String get newBeatMachine => 'MACHINE';

  @override
  String get newBeatChopDetail => 'RESÉQUENCER LE BREAK';

  @override
  String get newBeatKitDetail => 'HUIT ONE SHOTS';

  @override
  String get newBeatLength => 'LONGUEUR';

  @override
  String get newBeatCreate => 'CRÉER';

  @override
  String get songTitle => 'MORCEAU';

  @override
  String get songEmpty =>
      'RIEN D\'ARRANGÉ POUR L\'INSTANT\n\nAJOUTE LE BEAT OUVERT DEPUIS LA BARRE DU BAS, PUIS CHOISIS COMBIEN DE FOIS IL SE RÉPÈTE';

  @override
  String get libraryBreak => 'BREAK';

  @override
  String get libraryYours => 'À TOI';

  @override
  String get libraryImportFirst => 'IMPORTER LE TIEN';

  @override
  String get libraryImportAnother => 'IMPORTER UN AUTRE';

  @override
  String get libraryNote =>
      'UN BREAK ET UN KIT PAR PROJET. CHANGER LE BREAK NE SUPPRIME PAS TES MOTIFS.';

  @override
  String get exportTitleWav => 'EXPORTER EN WAV';

  @override
  String get exportTitleParts => 'EXPORTER LES PISTES';

  @override
  String get exportModeLoop => 'BOUCLE';

  @override
  String get exportModeSong => 'MORCEAU';

  @override
  String get exportModeParts => 'PISTES';

  @override
  String get exportMidiSlices => 'MIDI + SLICES';

  @override
  String get exportNothingArranged => 'RIEN D\'ARRANGÉ';

  @override
  String get exportRepeats => 'RÉPÉTITIONS';

  @override
  String get exportRender => 'RENDU ET PARTAGE';

  @override
  String get exportBuild => 'CRÉER ET PARTAGER';

  @override
  String exportSongDetail(String bars, int bpm) {
    return 'Tout l\'arrangement, $bars à $bpm BPM, 44.1 kHz 16 bit';
  }

  @override
  String exportLoopDetail(String bars, int bpm) {
    return '$bars à $bpm BPM, 44.1 kHz 16 bit';
  }

  @override
  String exportPartsDetail(String name, String content, int note) {
    return 'Le beat $name en fichier MIDI avec $content qu\'il joue, mappé depuis la note $note pour Kong et NN-XT';
  }

  @override
  String get exportPartsKit => 'le kit';

  @override
  String get exportPartsSlices => 'les slices';

  @override
  String get exportFailed => 'Échec de l\'export';

  @override
  String stepModStep(int number) {
    return 'PAS $number';
  }

  @override
  String get stepModEmpty => 'VIDE';

  @override
  String get stepModPlain => 'SIMPLE';

  @override
  String get stepModReverse => 'INVERSÉ';

  @override
  String get stepModRetrig => 'REDÉCL.';

  @override
  String get stepModPitchDown => 'PITCH BAS';

  @override
  String get stepModHalfSpeed => 'MI-VITESSE';

  @override
  String get kitHint => 'MAINTIENS UN PAD POUR VOL ET PITCH';

  @override
  String kitSlot(int number) {
    return 'EMPLACEMENT $number';
  }

  @override
  String get kitImportOneShot => 'IMPORTER UN ONE SHOT';

  @override
  String get kitImportOneShotPro => 'IMPORTER UN ONE SHOT  (PRO)';

  @override
  String get kitReplace => 'REMPLACER';

  @override
  String get kitUseKitSample => 'UTILISER LE SAMPLE DU KIT';

  @override
  String get subTitle => 'SUB SYNTHÉ';

  @override
  String get subClearLane => 'VIDER LA PISTE';

  @override
  String get subHint => 'GLISSE PITCH MAINTIENS ACCENT';

  @override
  String get importTitle => 'IMPORTER UN BREAK';

  @override
  String get importBars => 'MESURES';

  @override
  String get importTempo => 'TEMPO';

  @override
  String get importPreviewLoop => 'ÉCOUTER LA BOUCLE';

  @override
  String get importStop => 'STOP';

  @override
  String get importTap => 'TAP';

  @override
  String importTapCount(int count) {
    return 'TAP $count';
  }

  @override
  String get importUseBreak => 'UTILISER CE BREAK';

  @override
  String importTooFast(int bpm, String bars) {
    return 'CELA FAIT $bpm BPM SUR $bars. ESSAIE UN AUTRE NOMBRE DE MESURES.';
  }

  @override
  String get importTruncated =>
      'CE FICHIER DÉPASSAIT LA LIMITE D\'IMPORT ET A ÉTÉ COUPÉ.';

  @override
  String get importFailed => 'Échec de l\'import';

  @override
  String get importErrorPicker =>
      'Impossible d\'ouvrir le sélecteur de fichiers.';

  @override
  String get importErrorDecode => 'Ce fichier n\'a pas pu être décodé.';

  @override
  String get importErrorTooShort =>
      'Ce fichier est trop court pour être découpé.';

  @override
  String get proTitle => 'JUNGLENGINE PRO';

  @override
  String get proTagline => 'UN SEUL ACHAT. PAS D\'ABONNEMENT. PAS DE PUB.';

  @override
  String get proFreeHeader => 'DÉJÀ GRATUIT, ET ÇA LE RESTERA';

  @override
  String get proRestore => 'RESTAURER L\'ACHAT';

  @override
  String get proDebugUnlock => 'DEBUG : DÉBLOQUER SANS ACHETER';

  @override
  String get proHavePro => 'TU AS PRO';

  @override
  String get proWaiting => 'EN ATTENTE DE LA BOUTIQUE';

  @override
  String get proChecking => 'VÉRIFICATION';

  @override
  String get proUnavailableNow => 'INDISPONIBLE POUR LE MOMENT';

  @override
  String proGet(String price) {
    return 'OBTENIR PRO  $price';
  }

  @override
  String get proPurchasesOff => 'LES ACHATS SONT DÉSACTIVÉS SUR CET APPAREIL';

  @override
  String get proPurchaseFailed => 'L\'achat n\'a pas abouti.';

  @override
  String get proFeatureImportTitle => 'IMPORTE TON PROPRE AUDIO';

  @override
  String get proFeatureImportDetail =>
      'N\'importe quel break, n\'importe quel one shot, depuis Files, iCloud, Drive ou un message. Découpe-le, tape le tempo, chope-le.';

  @override
  String get proFeatureMidiTitle => 'EXPORT MIDI ET SLICES';

  @override
  String get proFeatureMidiDetail =>
      'Le beat en fichier MIDI et les samples qu\'il joue, mappés pour tomber directement dans Kong ou NN-XT.';

  @override
  String get proFeaturePacksTitle => 'PACKS DE SLICES';

  @override
  String get proFeaturePacksDetail =>
      'Des breaks et des kits faits pour ça, au fil des sorties.';

  @override
  String get proFreeBundled => 'Tous les breaks et kits inclus';

  @override
  String get proFreeMachines =>
      'Les deux machines, toute la grille, la piste sub';

  @override
  String get proFreeSongs => 'Morceaux et export WAV';

  @override
  String get proFreeNoAds => 'Aucune pub, jamais';
}
