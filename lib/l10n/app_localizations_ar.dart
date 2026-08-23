// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'junglEngine';

  @override
  String barCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مازورة',
      many: '$count مازورة',
      few: '$count مازورات',
      two: 'مازورتان',
      one: 'مازورة واحدة',
      zero: 'لا مازورة',
    );
    return '$_temp0';
  }

  @override
  String barCountSentence(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مازورة',
      many: '$count مازورة',
      few: '$count مازورات',
      two: 'مازورتان',
      one: 'مازورة واحدة',
      zero: 'لا مازورة',
    );
    return '$_temp0';
  }

  @override
  String barUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'مازورة',
      many: 'مازورة',
      few: 'مازورات',
      two: 'مازورتان',
      one: 'مازورة',
      zero: 'مازورة',
    );
    return '$_temp0';
  }

  @override
  String cardCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count بطاقة',
      many: '$count بطاقة',
      few: '$count بطاقات',
      two: 'بطاقتان',
      one: 'بطاقة واحدة',
      zero: 'لا بطاقة',
    );
    return '$_temp0';
  }

  @override
  String beatLabel(String name) {
    return 'بيت $name';
  }

  @override
  String get studioLoadingBreak => 'جارٍ تحميل البريك';

  @override
  String get studioEngineFailed => 'فشل محرّك الصوت';

  @override
  String get transportClear => 'مسح';

  @override
  String get transportArrangement => 'التوزيع';

  @override
  String get barStripLabel => 'مازورة';

  @override
  String actionAddBeat(String name) {
    return 'إضافة $name';
  }

  @override
  String get actionScramble => 'خلط';

  @override
  String get actionUndo => 'تراجع';

  @override
  String get actionExport => 'تصدير';

  @override
  String get beatBarSong => 'الأغنية';

  @override
  String get beatBarGrid => 'الشبكة';

  @override
  String get beatBarDup => 'نسخ';

  @override
  String get beatBarNew => 'جديد';

  @override
  String get beatBarDelete => 'حذف البيت';

  @override
  String get newBeatTitle => 'بيت جديد';

  @override
  String get newBeatMachine => 'الآلة';

  @override
  String get newBeatChopDetail => 'إعادة ترتيب البريك';

  @override
  String get newBeatKitDetail => 'ثماني ضربات مفردة';

  @override
  String get newBeatLength => 'الطول';

  @override
  String get newBeatCreate => 'إنشاء';

  @override
  String get songTitle => 'الأغنية';

  @override
  String get songEmpty =>
      'لا يوجد أي توزيع بعد\n\nأضف البيت المفتوح من الشريط بالأسفل، ثم حدّد عدد مرات تكراره';

  @override
  String get libraryBreak => 'البريك';

  @override
  String get libraryYours => 'خاصّتك';

  @override
  String get libraryImportFirst => 'استورد صوتك';

  @override
  String get libraryImportAnother => 'استورد صوتًا آخر';

  @override
  String get libraryNote =>
      'بريك واحد وKIT واحد لكل مشروع. تغيير البريك لا يمحو أنماطك.';

  @override
  String get exportTitleWav => 'تصدير WAV';

  @override
  String get exportTitleParts => 'تصدير الأجزاء';

  @override
  String get exportModeLoop => 'لوب';

  @override
  String get exportModeSong => 'أغنية';

  @override
  String get exportModeParts => 'أجزاء';

  @override
  String get exportMidiSlices => 'MIDI + SLICES';

  @override
  String get exportNothingArranged => 'لا يوجد توزيع';

  @override
  String get exportRepeats => 'التكرارات';

  @override
  String get exportRender => 'معالجة ومشاركة';

  @override
  String get exportBuild => 'إنشاء ومشاركة';

  @override
  String exportSongDetail(String bars, int bpm) {
    return 'التوزيع كاملًا، $bars على $bpm BPM، 44.1 kHz 16 bit';
  }

  @override
  String exportLoopDetail(String bars, int bpm) {
    return '$bars على $bpm BPM، 44.1 kHz 16 bit';
  }

  @override
  String exportPartsDetail(String name, String content, int note) {
    return 'البيت $name كملف MIDI مع $content التي يعزفها، موزّعة ابتداءً من النغمة $note لبرنامجي Kong وNN-XT';
  }

  @override
  String get exportPartsKit => 'الطقم';

  @override
  String get exportPartsSlices => 'المقاطع';

  @override
  String get exportFailed => 'فشل التصدير';

  @override
  String stepModStep(int number) {
    return 'الخطوة $number';
  }

  @override
  String get stepModEmpty => 'فارغة';

  @override
  String get stepModPlain => 'عادي';

  @override
  String get stepModReverse => 'معكوس';

  @override
  String get stepModRetrig => 'تكرار سريع';

  @override
  String get stepModPitchDown => 'خفض الطبقة';

  @override
  String get stepModHalfSpeed => 'نصف السرعة';

  @override
  String get kitHint => 'اضغط مطوّلًا على الپاد لضبط VOL وPITCH';

  @override
  String kitSlot(int number) {
    return 'الخانة $number';
  }

  @override
  String get kitImportOneShot => 'استيراد ضربة مفردة';

  @override
  String get kitImportOneShotPro => 'استيراد ضربة مفردة  (PRO)';

  @override
  String get kitReplace => 'استبدال';

  @override
  String get kitUseKitSample => 'استخدام عيّنة الطقم';

  @override
  String get subTitle => 'مركّب SUB';

  @override
  String get subClearLane => 'إفراغ المسار';

  @override
  String get subHint => 'اسحب لضبط PITCH واضغط مطوّلًا للتشديد';

  @override
  String get importTitle => 'استيراد بريك';

  @override
  String get importBars => 'المازورات';

  @override
  String get importTempo => 'الإيقاع';

  @override
  String get importPreviewLoop => 'استماع للّوب';

  @override
  String get importStop => 'إيقاف';

  @override
  String get importTap => 'نقر';

  @override
  String importTapCount(int count) {
    return 'نقر $count';
  }

  @override
  String get importUseBreak => 'استخدام هذا البريك';

  @override
  String importTooFast(int bpm, String bars) {
    return 'هذا يعني $bpm BPM على $bars. جرّب عددًا مختلفًا من المازورات.';
  }

  @override
  String get importTruncated => 'هذا الملف تجاوز حدّ الاستيراد فتمّ اقتطاعه.';

  @override
  String get importFailed => 'فشل الاستيراد';

  @override
  String get importErrorPicker => 'تعذّر فتح مُنتقي الملفات.';

  @override
  String get importErrorDecode => 'تعذّر فكّ ترميز هذا الملف.';

  @override
  String get importErrorTooShort => 'هذا الملف أقصر من أن يُقطّع.';

  @override
  String get proTitle => 'JUNGLENGINE PRO';

  @override
  String get proTagline => 'شراء واحد. بلا اشتراك. بلا إعلانات.';

  @override
  String get proFreeHeader => 'مجاني بالفعل، وسيبقى كذلك';

  @override
  String get proRestore => 'استعادة الشراء';

  @override
  String get proDebugUnlock => 'DEBUG: فتح بدون شراء';

  @override
  String get proHavePro => 'لديك PRO';

  @override
  String get proWaiting => 'بانتظار المتجر';

  @override
  String get proChecking => 'جارٍ التحقق';

  @override
  String get proUnavailableNow => 'غير متاح حاليًا';

  @override
  String proGet(String price) {
    return 'احصل على PRO  $price';
  }

  @override
  String get proPurchasesOff => 'المشتريات معطّلة على هذا الجهاز';

  @override
  String get proPurchaseFailed => 'لم تكتمل عملية الشراء.';

  @override
  String get proFeatureImportTitle => 'استورد صوتك الخاص';

  @override
  String get proFeatureImportDetail =>
      'أي بريك، وأي ضربة مفردة، من Files أو iCloud أو Drive أو من رسالة. قصّه، انقر الإيقاع، وقطّعه.';

  @override
  String get proFeatureMidiTitle => 'تصدير MIDI والمقاطع';

  @override
  String get proFeatureMidiDetail =>
      'البيت كملف MIDI مع العيّنات التي يعزفها، موزّعة لتدخل مباشرة في Kong أو NN-XT.';

  @override
  String get proFeaturePacksTitle => 'حزم المقاطع';

  @override
  String get proFeaturePacksDetail => 'بريكات وأطقم مصنوعة لهذا، كلّما صدرت.';

  @override
  String get proFreeBundled => 'كل البريكات والأطقم المضمّنة';

  @override
  String get proFreeMachines => 'كلتا الآلتين، والشبكة بأكملها، ومسار sub';

  @override
  String get proFreeSongs => 'الأغاني وتصدير WAV';

  @override
  String get proFreeNoAds => 'بلا إعلانات، أبدًا';
}
