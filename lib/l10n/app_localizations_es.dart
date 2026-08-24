// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'junglEngine';

  @override
  String barCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count COMPASES',
      one: '1 COMPÁS',
    );
    return '$_temp0';
  }

  @override
  String barCountSentence(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count compases',
      one: '1 compás',
    );
    return '$_temp0';
  }

  @override
  String barUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'COMPASES',
      one: 'COMPÁS',
    );
    return '$_temp0';
  }

  @override
  String cardCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count TARJETAS',
      one: '1 TARJETA',
    );
    return '$_temp0';
  }

  @override
  String beatLabel(String name) {
    return 'BEAT $name';
  }

  @override
  String get studioLoadingBreak => 'CARGANDO BREAK';

  @override
  String get studioEngineFailed => 'FALLÓ EL MOTOR DE AUDIO';

  @override
  String get transportClear => 'BORRAR';

  @override
  String get transportArrangement => 'ARREGLO';

  @override
  String get barStripLabel => 'COMP';

  @override
  String actionAddBeat(String name) {
    return 'AÑADIR $name';
  }

  @override
  String get actionScramble => 'REVOLVER';

  @override
  String get actionUndo => 'DESHACER';

  @override
  String get actionExport => 'EXPORTAR';

  @override
  String get beatBarSong => 'TEMA';

  @override
  String get beatBarGrid => 'REJILLA';

  @override
  String get beatBarDup => 'DUP';

  @override
  String get beatBarNew => 'NUEVO';

  @override
  String get beatBarDelete => 'BORRAR BEAT';

  @override
  String get newBeatTitle => 'NUEVO BEAT';

  @override
  String get newBeatMachine => 'MÁQUINA';

  @override
  String get newBeatChopDetail => 'RESECUENCIAR EL BREAK';

  @override
  String get newBeatKitDetail => 'OCHO ONE SHOTS';

  @override
  String get newBeatLength => 'LONGITUD';

  @override
  String get newBeatCreate => 'CREAR';

  @override
  String get songTitle => 'TEMA';

  @override
  String get songEmpty =>
      'AÚN NO HAY NADA ARREGLADO\n\nAÑADE EL BEAT QUE TIENES ABIERTO DESDE LA BARRA DE ABAJO Y ELIGE CUÁNTAS VECES SE REPITE';

  @override
  String get libraryBreak => 'BREAK';

  @override
  String get libraryYours => 'TUYO';

  @override
  String get libraryImportFirst => 'IMPORTA EL TUYO';

  @override
  String get libraryImportAnother => 'IMPORTAR OTRO';

  @override
  String get libraryNote =>
      'UN BREAK Y UN KIT POR PROYECTO. CAMBIAR EL BREAK NO BORRA TUS PATRONES.';

  @override
  String get exportTitleWav => 'EXPORTAR WAV';

  @override
  String get exportTitleParts => 'EXPORTAR PISTAS';

  @override
  String get exportModeLoop => 'LOOP';

  @override
  String get exportModeSong => 'TEMA';

  @override
  String get exportModeParts => 'PISTAS';

  @override
  String get exportMidiSlices => 'MIDI + SLICES';

  @override
  String get exportNothingArranged => 'NADA ARREGLADO';

  @override
  String get exportRepeats => 'REPETICIONES';

  @override
  String get exportRender => 'RENDERIZAR Y COMPARTIR';

  @override
  String get exportBuild => 'CREAR Y COMPARTIR';

  @override
  String exportSongDetail(String bars, int bpm) {
    return 'Todo el arreglo, $bars a $bpm BPM, 44.1 kHz 16 bit';
  }

  @override
  String exportLoopDetail(String bars, int bpm) {
    return '$bars a $bpm BPM, 44.1 kHz 16 bit';
  }

  @override
  String exportPartsDetail(String name, String content, int note) {
    return 'El beat $name como archivo MIDI junto con $content que suena, mapeado desde la nota $note para Kong y NN-XT';
  }

  @override
  String get exportPartsKit => 'el kit';

  @override
  String get exportPartsSlices => 'los slices';

  @override
  String get exportFailed => 'Falló la exportación';

  @override
  String stepModStep(int number) {
    return 'PASO $number';
  }

  @override
  String get stepModEmpty => 'VACÍO';

  @override
  String get stepModPlain => 'NORMAL';

  @override
  String get stepModReverse => 'REVÉS';

  @override
  String get stepModRetrig => 'REDISPARO';

  @override
  String get stepModPitchDown => 'TONO ABAJO';

  @override
  String get stepModHalfSpeed => 'MITAD VEL.';

  @override
  String get kitHint => 'MANTÉN UN PAD PARA VOL Y PITCH';

  @override
  String kitSlot(int number) {
    return 'RANURA $number';
  }

  @override
  String get kitImportOneShot => 'IMPORTAR ONE SHOT';

  @override
  String get kitImportOneShotPro => 'IMPORTAR ONE SHOT  (PRO)';

  @override
  String get kitReplace => 'REEMPLAZAR';

  @override
  String get kitUseKitSample => 'USAR SAMPLE DEL KIT';

  @override
  String get subTitle => 'SUB SINTE';

  @override
  String get subClearLane => 'VACIAR PISTA';

  @override
  String get subHint => 'ARRASTRA PITCH MANTÉN ACENTO';

  @override
  String get subEdit => 'EDITAR NOTAS';

  @override
  String get subNotesTitle => 'SUB NOTAS';

  @override
  String get subEditorHint => 'TOCA UNA CASILLA PARA PONER UNA NOTA';

  @override
  String get subAccent => 'ACENTO';

  @override
  String get subClearNote => 'BORRAR NOTA';

  @override
  String get subMoveEarlier => 'ADELANTAR LA NOTA UN PASO';

  @override
  String get subMoveLater => 'ATRASAR LA NOTA UN PASO';

  @override
  String get importTitle => 'IMPORTAR BREAK';

  @override
  String get importBars => 'COMPASES';

  @override
  String get importTempo => 'TEMPO';

  @override
  String get importPreviewLoop => 'ESCUCHAR LOOP';

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
    return 'ESO SON $bpm BPM CON $bars. PRUEBA OTRO NÚMERO DE COMPASES.';
  }

  @override
  String get importTruncated =>
      'ESE ARCHIVO SUPERABA EL LÍMITE DE IMPORTACIÓN Y SE HA RECORTADO.';

  @override
  String get importFailed => 'Falló la importación';

  @override
  String get importErrorPicker => 'No se pudo abrir el selector de archivos.';

  @override
  String get importErrorDecode => 'Ese archivo no se pudo decodificar.';

  @override
  String get importErrorTooShort =>
      'Ese archivo es demasiado corto para trocearlo.';

  @override
  String get proTitle => 'JUNGLENGINE PRO';

  @override
  String get proTagline => 'UN SOLO PAGO. SIN SUSCRIPCIÓN. SIN ANUNCIOS.';

  @override
  String get proFreeHeader => 'YA ES GRATIS, Y SEGUIRÁ SIÉNDOLO';

  @override
  String get proRestore => 'RESTAURAR COMPRA';

  @override
  String get proDebugUnlock => 'DEBUG: DESBLOQUEAR SIN COMPRAR';

  @override
  String get proHavePro => 'TIENES PRO';

  @override
  String get proWaiting => 'ESPERANDO A LA TIENDA';

  @override
  String get proChecking => 'COMPROBANDO';

  @override
  String get proUnavailableNow => 'NO DISPONIBLE AHORA MISMO';

  @override
  String proGet(String price) {
    return 'CONSEGUIR PRO  $price';
  }

  @override
  String get proPurchasesOff =>
      'LAS COMPRAS ESTÁN DESACTIVADAS EN ESTE DISPOSITIVO';

  @override
  String get proPurchaseFailed => 'La compra no se completó.';

  @override
  String get proFeatureImportTitle => 'IMPORTA TU PROPIO AUDIO';

  @override
  String get proFeatureImportDetail =>
      'Cualquier break, cualquier one shot, desde Files, iCloud, Drive o un mensaje. Recórtalo, marca el tempo, trocéalo.';

  @override
  String get proFeatureMidiTitle => 'EXPORTAR MIDI Y SLICES';

  @override
  String get proFeatureMidiDetail =>
      'El beat como archivo MIDI y los samples que suenan, mapeados para caer directos en Kong o NN-XT.';

  @override
  String get proFeaturePacksTitle => 'PACKS DE SLICES';

  @override
  String get proFeaturePacksDetail =>
      'Breaks y kits hechos para esto, según vayan saliendo.';

  @override
  String get proFreeBundled => 'Todos los breaks y kits incluidos';

  @override
  String get proFreeMachines =>
      'Las dos máquinas, toda la rejilla, la pista de sub';

  @override
  String get proFreeSongs => 'Temas y exportación WAV';

  @override
  String get proFreeNoAds => 'Sin anuncios, nunca';
}
