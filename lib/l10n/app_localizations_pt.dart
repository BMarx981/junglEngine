// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'junglEngine';

  @override
  String barCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count COMPASSOS',
      one: '1 COMPASSO',
    );
    return '$_temp0';
  }

  @override
  String barCountSentence(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count compassos',
      one: '1 compasso',
    );
    return '$_temp0';
  }

  @override
  String barUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'COMPASSOS',
      one: 'COMPASSO',
    );
    return '$_temp0';
  }

  @override
  String cardCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count CARTÕES',
      one: '1 CARTÃO',
    );
    return '$_temp0';
  }

  @override
  String beatLabel(String name) {
    return 'BEAT $name';
  }

  @override
  String get studioLoadingBreak => 'A CARREGAR O BREAK';

  @override
  String get studioEngineFailed => 'FALHA NO MOTOR DE ÁUDIO';

  @override
  String get transportClear => 'LIMPAR';

  @override
  String get transportArrangement => 'ARRANJO';

  @override
  String get barStripLabel => 'COMP';

  @override
  String actionAddBeat(String name) {
    return 'ADICIONAR $name';
  }

  @override
  String get actionScramble => 'BARALHAR';

  @override
  String get actionUndo => 'DESFAZER';

  @override
  String get actionExport => 'EXPORTAR';

  @override
  String get beatBarSong => 'MÚSICA';

  @override
  String get beatBarGrid => 'GRELHA';

  @override
  String get beatBarDup => 'DUP';

  @override
  String get beatBarNew => 'NOVO';

  @override
  String get beatBarDelete => 'APAGAR BEAT';

  @override
  String get newBeatTitle => 'NOVO BEAT';

  @override
  String get newBeatMachine => 'MÁQUINA';

  @override
  String get newBeatChopDetail => 'RESSEQUENCIAR O BREAK';

  @override
  String get newBeatKitDetail => 'OITO ONE SHOTS';

  @override
  String get newBeatLength => 'DURAÇÃO';

  @override
  String get newBeatCreate => 'CRIAR';

  @override
  String get songTitle => 'MÚSICA';

  @override
  String get songEmpty =>
      'AINDA NÃO HÁ NADA ARRANJADO\n\nADICIONA O BEAT QUE TENS ABERTO A PARTIR DA BARRA DE BAIXO E ESCOLHE QUANTAS VEZES SE REPETE';

  @override
  String get libraryBreak => 'BREAK';

  @override
  String get libraryYours => 'TEU';

  @override
  String get libraryImportFirst => 'IMPORTA O TEU';

  @override
  String get libraryImportAnother => 'IMPORTAR OUTRO';

  @override
  String get libraryNote =>
      'UM BREAK E UM KIT POR PROJETO. TROCAR O BREAK NÃO APAGA OS TEUS PADRÕES.';

  @override
  String get exportTitleWav => 'EXPORTAR WAV';

  @override
  String get exportTitleParts => 'EXPORTAR PISTAS';

  @override
  String get exportModeLoop => 'LOOP';

  @override
  String get exportModeSong => 'MÚSICA';

  @override
  String get exportModeParts => 'PISTAS';

  @override
  String get exportMidiSlices => 'MIDI + SLICES';

  @override
  String get exportNothingArranged => 'NADA ARRANJADO';

  @override
  String get exportRepeats => 'REPETIÇÕES';

  @override
  String get exportRender => 'RENDERIZAR E PARTILHAR';

  @override
  String get exportBuild => 'CRIAR E PARTILHAR';

  @override
  String exportSongDetail(String bars, int bpm) {
    return 'Todo o arranjo, $bars a $bpm BPM, 44.1 kHz 16 bit';
  }

  @override
  String exportLoopDetail(String bars, int bpm) {
    return '$bars a $bpm BPM, 44.1 kHz 16 bit';
  }

  @override
  String exportPartsDetail(String name, String content, int note) {
    return 'O beat $name como ficheiro MIDI e $content que toca, mapeado a partir da nota $note para Kong e NN-XT';
  }

  @override
  String get exportPartsKit => 'o kit';

  @override
  String get exportPartsSlices => 'os slices';

  @override
  String get exportFailed => 'A exportação falhou';

  @override
  String stepModStep(int number) {
    return 'PASSO $number';
  }

  @override
  String get stepModEmpty => 'VAZIO';

  @override
  String get stepModPlain => 'NORMAL';

  @override
  String get stepModReverse => 'INVERTIDO';

  @override
  String get stepModRetrig => 'REDISPARO';

  @override
  String get stepModPitchDown => 'TOM ABAIXO';

  @override
  String get stepModHalfSpeed => 'MEIA VEL.';

  @override
  String get kitHint => 'SEGURA UM PAD PARA VOL E PITCH';

  @override
  String kitSlot(int number) {
    return 'SLOT $number';
  }

  @override
  String get kitImportOneShot => 'IMPORTAR ONE SHOT';

  @override
  String get kitImportOneShotPro => 'IMPORTAR ONE SHOT  (PRO)';

  @override
  String get kitReplace => 'SUBSTITUIR';

  @override
  String get kitUseKitSample => 'USAR SAMPLE DO KIT';

  @override
  String get subTitle => 'SUB SINTE';

  @override
  String get subClearLane => 'LIMPAR PISTA';

  @override
  String get subHint => 'ARRASTA PITCH SEGURA ACENTO';

  @override
  String get subEdit => 'EDITAR NOTAS';

  @override
  String get subNotesTitle => 'NOTAS SUB';

  @override
  String get subEditorHint => 'TOQUE NUMA CASA PARA COLOCAR UMA NOTA';

  @override
  String get subAccent => 'ACENTO';

  @override
  String get subClearNote => 'APAGAR NOTA';

  @override
  String get subMoveEarlier => 'ADIANTAR A NOTA UM PASSO';

  @override
  String get subMoveLater => 'ATRASAR A NOTA UM PASSO';

  @override
  String get importTitle => 'IMPORTAR BREAK';

  @override
  String get importBars => 'COMPASSOS';

  @override
  String get importTempo => 'ANDAMENTO';

  @override
  String get importPreviewLoop => 'OUVIR O LOOP';

  @override
  String get importStop => 'PARAR';

  @override
  String get importTap => 'TAP';

  @override
  String importTapCount(int count) {
    return 'TAP $count';
  }

  @override
  String get importUseBreak => 'USAR ESTE BREAK';

  @override
  String importTooFast(int bpm, String bars) {
    return 'ISSO DÁ $bpm BPM COM $bars. EXPERIMENTA OUTRO NÚMERO DE COMPASSOS.';
  }

  @override
  String get importTruncated =>
      'ESSE FICHEIRO PASSAVA O LIMITE DE IMPORTAÇÃO E FOI CORTADO.';

  @override
  String get importFailed => 'A importação falhou';

  @override
  String get importErrorPicker =>
      'Não foi possível abrir o seletor de ficheiros.';

  @override
  String get importErrorDecode => 'Esse ficheiro não pôde ser descodificado.';

  @override
  String get importErrorTooShort =>
      'Esse ficheiro é demasiado curto para cortar.';

  @override
  String get proTitle => 'JUNGLENGINE PRO';

  @override
  String get proTagline => 'UMA SÓ COMPRA. SEM SUBSCRIÇÃO. SEM ANÚNCIOS.';

  @override
  String get proFreeHeader => 'JÁ É GRÁTIS, E VAI CONTINUAR';

  @override
  String get proRestore => 'RESTAURAR COMPRA';

  @override
  String get proDebugUnlock => 'DEBUG: DESBLOQUEAR SEM COMPRAR';

  @override
  String get proHavePro => 'TENS O PRO';

  @override
  String get proWaiting => 'À ESPERA DA LOJA';

  @override
  String get proChecking => 'A VERIFICAR';

  @override
  String get proUnavailableNow => 'INDISPONÍVEL DE MOMENTO';

  @override
  String proGet(String price) {
    return 'OBTER PRO  $price';
  }

  @override
  String get proPurchasesOff => 'AS COMPRAS ESTÃO DESLIGADAS NESTE DISPOSITIVO';

  @override
  String get proPurchaseFailed => 'A compra não foi concluída.';

  @override
  String get proFeatureImportTitle => 'IMPORTA O TEU PRÓPRIO ÁUDIO';

  @override
  String get proFeatureImportDetail =>
      'Qualquer break, qualquer one shot, do Files, iCloud, Drive ou de uma mensagem. Corta, marca o andamento, fatia.';

  @override
  String get proFeatureMidiTitle => 'EXPORTAR MIDI E SLICES';

  @override
  String get proFeatureMidiDetail =>
      'O beat como ficheiro MIDI e os samples que toca, mapeados para cair direitos no Kong ou no NN-XT.';

  @override
  String get proFeaturePacksTitle => 'PACKS DE SLICES';

  @override
  String get proFeaturePacksDetail =>
      'Breaks e kits feitos para isto, à medida que forem saindo.';

  @override
  String get proFreeBundled => 'Tudo o que vem no pack Starter';

  @override
  String get proFreeMachines =>
      'As duas máquinas, a grelha toda, a pista de sub';

  @override
  String get proFreeSongs => 'Músicas e exportação WAV';

  @override
  String get proFreeNoAds => 'Sem anúncios, nunca';
}
