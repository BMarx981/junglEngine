// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'junglEngine';

  @override
  String barCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ТАКТА',
      many: '$count ТАКТОВ',
      few: '$count ТАКТА',
      one: '$count ТАКТ',
    );
    return '$_temp0';
  }

  @override
  String barCountSentence(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count такта',
      many: '$count тактов',
      few: '$count такта',
      one: '$count такт',
    );
    return '$_temp0';
  }

  @override
  String barUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ТАКТА',
      many: 'ТАКТОВ',
      few: 'ТАКТА',
      one: 'ТАКТ',
    );
    return '$_temp0';
  }

  @override
  String cardCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count КАРТЫ',
      many: '$count КАРТ',
      few: '$count КАРТЫ',
      one: '$count КАРТА',
    );
    return '$_temp0';
  }

  @override
  String beatLabel(String name) {
    return 'БИТ $name';
  }

  @override
  String get studioLoadingBreak => 'ЗАГРУЗКА БРЕЙКА';

  @override
  String get studioEngineFailed => 'СБОЙ ЗВУКОВОГО ДВИЖКА';

  @override
  String get transportClear => 'СБРОС';

  @override
  String get transportArrangement => 'АРАНЖИРОВКА';

  @override
  String get barStripLabel => 'ТАКТ';

  @override
  String actionAddBeat(String name) {
    return 'ДОБАВИТЬ $name';
  }

  @override
  String get actionScramble => 'ПЕРЕМЕШАТЬ';

  @override
  String get actionUndo => 'ОТМЕНА';

  @override
  String get actionExport => 'ЭКСПОРТ';

  @override
  String get beatBarSong => 'ТРЕК';

  @override
  String get beatBarGrid => 'СЕТКА';

  @override
  String get beatBarDup => 'КОП';

  @override
  String get beatBarNew => 'НОВЫЙ';

  @override
  String get beatBarDelete => 'УДАЛИТЬ БИТ';

  @override
  String get newBeatTitle => 'НОВЫЙ БИТ';

  @override
  String get newBeatMachine => 'МАШИНА';

  @override
  String get newBeatChopDetail => 'ПЕРЕСОБРАТЬ БРЕЙК';

  @override
  String get newBeatKitDetail => 'ВОСЕМЬ ONE SHOT';

  @override
  String get newBeatLength => 'ДЛИНА';

  @override
  String get newBeatCreate => 'СОЗДАТЬ';

  @override
  String get songTitle => 'ТРЕК';

  @override
  String get songEmpty =>
      'ПОКА НИЧЕГО НЕ СОБРАНО\n\nДОБАВЬ ОТКРЫТЫЙ БИТ С ПАНЕЛИ СНИЗУ И ЗАДАЙ, СКОЛЬКО РАЗ ОН ПОВТОРИТСЯ';

  @override
  String get libraryBreak => 'БРЕЙК';

  @override
  String get libraryYours => 'СВОЙ';

  @override
  String get libraryImportFirst => 'ЗАГРУЗИТЬ СВОЙ';

  @override
  String get libraryImportAnother => 'ЗАГРУЗИТЬ ДРУГОЙ';

  @override
  String get libraryNote =>
      'ОДИН БРЕЙК И ОДИН KIT НА ПРОЕКТ. СМЕНА БРЕЙКА НЕ УДАЛЯЕТ ТВОИ ПАТТЕРНЫ.';

  @override
  String get exportTitleWav => 'ЭКСПОРТ WAV';

  @override
  String get exportTitleParts => 'ЭКСПОРТ ПАРТИЙ';

  @override
  String get exportModeLoop => 'ЛУП';

  @override
  String get exportModeSong => 'ТРЕК';

  @override
  String get exportModeParts => 'ПАРТИИ';

  @override
  String get exportMidiSlices => 'MIDI + SLICES';

  @override
  String get exportNothingArranged => 'НИЧЕГО НЕ СОБРАНО';

  @override
  String get exportRepeats => 'ПОВТОРЫ';

  @override
  String get exportRender => 'СВЕСТИ И ОТПРАВИТЬ';

  @override
  String get exportBuild => 'СОБРАТЬ И ОТПРАВИТЬ';

  @override
  String exportSongDetail(String bars, int bpm) {
    return 'Вся аранжировка, $bars на $bpm BPM, 44.1 kHz 16 bit';
  }

  @override
  String exportLoopDetail(String bars, int bpm) {
    return '$bars на $bpm BPM, 44.1 kHz 16 bit';
  }

  @override
  String exportPartsDetail(String name, String content, int note) {
    return 'Бит $name как MIDI-файл и $content, которые он играет, с раскладкой от ноты $note для Kong и NN-XT';
  }

  @override
  String get exportPartsKit => 'kit';

  @override
  String get exportPartsSlices => 'слайсы';

  @override
  String get exportFailed => 'Не удалось экспортировать';

  @override
  String stepModStep(int number) {
    return 'ШАГ $number';
  }

  @override
  String get stepModEmpty => 'ПУСТО';

  @override
  String get stepModPlain => 'ОБЫЧНО';

  @override
  String get stepModReverse => 'РЕВЕРС';

  @override
  String get stepModRetrig => 'РЕТРИГ';

  @override
  String get stepModPitchDown => 'НИЖЕ ТОНОМ';

  @override
  String get stepModHalfSpeed => 'ПОЛСКОРОСТИ';

  @override
  String get kitHint => 'УДЕРЖИ ПЭД ДЛЯ VOL И PITCH';

  @override
  String kitSlot(int number) {
    return 'СЛОТ $number';
  }

  @override
  String get kitImportOneShot => 'ЗАГРУЗИТЬ ONE SHOT';

  @override
  String get kitImportOneShotPro => 'ЗАГРУЗИТЬ ONE SHOT  (PRO)';

  @override
  String get kitReplace => 'ЗАМЕНИТЬ';

  @override
  String get kitUseKitSample => 'ВЕРНУТЬ СЭМПЛ KIT';

  @override
  String get subTitle => 'SUB СИНТ';

  @override
  String get subClearLane => 'ОЧИСТИТЬ ДОРОЖКУ';

  @override
  String get subHint => 'ТЯНИ PITCH УДЕРЖИ АКЦЕНТ';

  @override
  String get subEdit => 'РЕДАКТИРОВАТЬ НОТЫ';

  @override
  String get subNotesTitle => 'НОТЫ SUB';

  @override
  String get subEditorHint => 'НАЖМИ НА КЛЕТКУ, ЧТОБЫ ПОСТАВИТЬ НОТУ';

  @override
  String get subAccent => 'АКЦЕНТ';

  @override
  String get subClearNote => 'УБРАТЬ НОТУ';

  @override
  String get subMoveEarlier => 'СДВИНУТЬ НОТУ НА ШАГ РАНЬШЕ';

  @override
  String get subMoveLater => 'СДВИНУТЬ НОТУ НА ШАГ ПОЗЖЕ';

  @override
  String get importTitle => 'ЗАГРУЗИТЬ БРЕЙК';

  @override
  String get importBars => 'ТАКТЫ';

  @override
  String get importTempo => 'ТЕМП';

  @override
  String get importPreviewLoop => 'ПРОСЛУШАТЬ ЛУП';

  @override
  String get importStop => 'СТОП';

  @override
  String get importTap => 'ТАП';

  @override
  String importTapCount(int count) {
    return 'ТАП $count';
  }

  @override
  String get importUseBreak => 'ВЗЯТЬ ЭТОТ БРЕЙК';

  @override
  String importTooFast(int bpm, String bars) {
    return 'ЭТО $bpm BPM НА $bars. ПОПРОБУЙ ДРУГОЕ ЧИСЛО ТАКТОВ.';
  }

  @override
  String get importTruncated =>
      'ФАЙЛ ОКАЗАЛСЯ ДЛИННЕЕ ЛИМИТА ЗАГРУЗКИ И БЫЛ ОБРЕЗАН.';

  @override
  String get importFailed => 'Не удалось загрузить';

  @override
  String get importErrorPicker => 'Не удалось открыть выбор файлов.';

  @override
  String get importErrorDecode => 'Этот файл не удалось декодировать.';

  @override
  String get importErrorTooShort =>
      'Этот файл слишком короткий, чтобы его нарезать.';

  @override
  String get proTitle => 'JUNGLENGINE PRO';

  @override
  String get proTagline => 'ОДНА ПОКУПКА. БЕЗ ПОДПИСКИ. БЕЗ РЕКЛАМЫ.';

  @override
  String get proFreeHeader => 'УЖЕ БЕСПЛАТНО И ОСТАНЕТСЯ ТАКИМ';

  @override
  String get proRestore => 'ВОССТАНОВИТЬ ПОКУПКУ';

  @override
  String get proDebugUnlock => 'DEBUG: ОТКРЫТЬ БЕЗ ПОКУПКИ';

  @override
  String get proHavePro => 'У ТЕБЯ ЕСТЬ PRO';

  @override
  String get proWaiting => 'ЖДЁМ МАГАЗИН';

  @override
  String get proChecking => 'ПРОВЕРКА';

  @override
  String get proUnavailableNow => 'СЕЙЧАС НЕДОСТУПНО';

  @override
  String proGet(String price) {
    return 'КУПИТЬ PRO  $price';
  }

  @override
  String get proPurchasesOff => 'ПОКУПКИ ОТКЛЮЧЕНЫ НА ЭТОМ УСТРОЙСТВЕ';

  @override
  String get proPurchaseFailed => 'Покупка не прошла.';

  @override
  String get proFeatureImportTitle => 'СВОЁ СОБСТВЕННОЕ АУДИО';

  @override
  String get proFeatureImportDetail =>
      'Любой брейк, любой one shot, из Files, iCloud, Drive или из сообщения. Обрежь, отстучи темп, нарежь.';

  @override
  String get proFeatureMidiTitle => 'ЭКСПОРТ MIDI И СЛАЙСОВ';

  @override
  String get proFeatureMidiDetail =>
      'Бит как MIDI-файл и сэмплы, которые он играет, разложенные так, чтобы сразу лечь в Kong или NN-XT.';

  @override
  String get proFeaturePacksTitle => 'ПАКИ СЛАЙСОВ';

  @override
  String get proFeaturePacksDetail =>
      'Брейки и киты, сделанные под это, по мере выхода.';

  @override
  String get proFreeBundled => 'Все встроенные брейки и киты';

  @override
  String get proFreeMachines => 'Обе машины, вся сетка, дорожка sub';

  @override
  String get proFreeSongs => 'Треки и экспорт в WAV';

  @override
  String get proFreeNoAds => 'Никакой рекламы, никогда';
}
