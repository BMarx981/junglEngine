// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'junglEngine';

  @override
  String barCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ô NHỊP',
    );
    return '$_temp0';
  }

  @override
  String barCountSentence(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ô nhịp',
    );
    return '$_temp0';
  }

  @override
  String barUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ô NHỊP',
    );
    return '$_temp0';
  }

  @override
  String cardCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count THẺ',
    );
    return '$_temp0';
  }

  @override
  String beatLabel(String name) {
    return 'BEAT $name';
  }

  @override
  String get studioLoadingBreak => 'ĐANG TẢI BREAK';

  @override
  String get studioEngineFailed => 'ENGINE ÂM THANH LỖI';

  @override
  String get transportClear => 'XOÁ';

  @override
  String get transportArrangement => 'PHỐI';

  @override
  String get barStripLabel => 'NHỊP';

  @override
  String actionAddBeat(String name) {
    return 'THÊM $name';
  }

  @override
  String get actionScramble => 'XÁO';

  @override
  String get actionUndo => 'HOÀN TÁC';

  @override
  String get actionExport => 'XUẤT';

  @override
  String get beatBarSong => 'BÀI';

  @override
  String get beatBarGrid => 'LƯỚI';

  @override
  String get beatBarDup => 'NHÂN';

  @override
  String get beatBarNew => 'MỚI';

  @override
  String get beatBarDelete => 'XOÁ BEAT';

  @override
  String get newBeatTitle => 'BEAT MỚI';

  @override
  String get newBeatMachine => 'MÁY';

  @override
  String get newBeatChopDetail => 'XẾP LẠI BREAK';

  @override
  String get newBeatKitDetail => 'TÁM ONE SHOT';

  @override
  String get newBeatLength => 'ĐỘ DÀI';

  @override
  String get newBeatCreate => 'TẠO';

  @override
  String get songTitle => 'BÀI';

  @override
  String get songEmpty =>
      'CHƯA PHỐI GÌ CẢ\n\nTHÊM BEAT ĐANG MỞ TỪ THANH BÊN DƯỚI, RỒI ĐẶT SỐ LẦN LẶP';

  @override
  String get libraryBreak => 'BREAK';

  @override
  String get libraryYours => 'CỦA BẠN';

  @override
  String get libraryImportFirst => 'NHẬP CỦA BẠN';

  @override
  String get libraryImportAnother => 'NHẬP CÁI KHÁC';

  @override
  String get libraryNote =>
      'MỖI DỰ ÁN MỘT BREAK VÀ MỘT KIT. ĐỔI BREAK KHÔNG XOÁ CÁC MẪU CỦA BẠN.';

  @override
  String get exportTitleWav => 'XUẤT WAV';

  @override
  String get exportTitleParts => 'XUẤT CÁC PHẦN';

  @override
  String get exportModeLoop => 'LOOP';

  @override
  String get exportModeSong => 'BÀI';

  @override
  String get exportModeParts => 'PHẦN';

  @override
  String get exportMidiSlices => 'MIDI + SLICES';

  @override
  String get exportNothingArranged => 'CHƯA PHỐI GÌ';

  @override
  String get exportRepeats => 'SỐ LẦN LẶP';

  @override
  String get exportRender => 'KẾT XUẤT VÀ CHIA SẺ';

  @override
  String get exportBuild => 'TẠO VÀ CHIA SẺ';

  @override
  String exportSongDetail(String bars, int bpm) {
    return 'Toàn bộ bản phối, $bars ở $bpm BPM, 44.1 kHz 16 bit';
  }

  @override
  String exportLoopDetail(String bars, int bpm) {
    return '$bars ở $bpm BPM, 44.1 kHz 16 bit';
  }

  @override
  String exportPartsDetail(String name, String content, int note) {
    return 'Beat $name dưới dạng tệp MIDI cùng $content mà nó chơi, ánh xạ từ nốt $note cho Kong và NN-XT';
  }

  @override
  String get exportPartsKit => 'bộ kit';

  @override
  String get exportPartsSlices => 'các slice';

  @override
  String get exportFailed => 'Xuất thất bại';

  @override
  String stepModStep(int number) {
    return 'BƯỚC $number';
  }

  @override
  String get stepModEmpty => 'TRỐNG';

  @override
  String get stepModPlain => 'THƯỜNG';

  @override
  String get stepModReverse => 'NGƯỢC';

  @override
  String get stepModRetrig => 'LẶP NHANH';

  @override
  String get stepModPitchDown => 'HẠ CAO ĐỘ';

  @override
  String get stepModHalfSpeed => 'NỬA TỐC';

  @override
  String get kitHint => 'GIỮ MỘT PAD ĐỂ CHỈNH VOL VÀ PITCH';

  @override
  String kitSlot(int number) {
    return 'Ô $number';
  }

  @override
  String get kitImportOneShot => 'NHẬP ONE SHOT';

  @override
  String get kitImportOneShotPro => 'NHẬP ONE SHOT  (PRO)';

  @override
  String get kitReplace => 'THAY';

  @override
  String get kitUseKitSample => 'DÙNG SAMPLE CỦA KIT';

  @override
  String get subTitle => 'SUB SYNTH';

  @override
  String get subClearLane => 'XOÁ LÀN';

  @override
  String get subHint => 'KÉO ĐỂ CHỈNH PITCH GIỮ ĐỂ NHẤN';

  @override
  String get subEdit => 'SỬA NỐT';

  @override
  String get subNotesTitle => 'NỐT SUB';

  @override
  String get subEditorHint => 'CHẠM VÀO Ô ĐỂ ĐẶT MỘT NỐT';

  @override
  String get subAccent => 'NHẤN';

  @override
  String get subClearNote => 'XOÁ NỐT';

  @override
  String get subMoveEarlier => 'DỜI NỐT SỚM MỘT BƯỚC';

  @override
  String get subMoveLater => 'DỜI NỐT TRỄ MỘT BƯỚC';

  @override
  String get importTitle => 'NHẬP BREAK';

  @override
  String get importBars => 'Ô NHỊP';

  @override
  String get importTempo => 'TEMPO';

  @override
  String get importPreviewLoop => 'NGHE THỬ LOOP';

  @override
  String get importStop => 'DỪNG';

  @override
  String get importTap => 'GÕ';

  @override
  String importTapCount(int count) {
    return 'GÕ $count';
  }

  @override
  String get importUseBreak => 'DÙNG BREAK NÀY';

  @override
  String importTooFast(int bpm, String bars) {
    return 'VẬY LÀ $bpm BPM VỚI $bars. THỬ SỐ Ô NHỊP KHÁC XEM.';
  }

  @override
  String get importTruncated =>
      'TỆP NÀY DÀI HƠN GIỚI HẠN NHẬP NÊN ĐÃ BỊ CẮT BỚT.';

  @override
  String get importFailed => 'Nhập thất bại';

  @override
  String get importErrorPicker => 'Không mở được trình chọn tệp.';

  @override
  String get importErrorDecode => 'Không giải mã được tệp này.';

  @override
  String get importErrorTooShort => 'Tệp này quá ngắn để cắt.';

  @override
  String get proTitle => 'JUNGLENGINE PRO';

  @override
  String get proTagline => 'MUA MỘT LẦN. KHÔNG THUÊ BAO. KHÔNG QUẢNG CÁO.';

  @override
  String get proFreeHeader => 'VỐN ĐÃ MIỄN PHÍ, VÀ SẼ LUÔN NHƯ VẬY';

  @override
  String get proRestore => 'KHÔI PHỤC GIAO DỊCH';

  @override
  String get proDebugUnlock => 'DEBUG: MỞ KHOÁ KHÔNG CẦN MUA';

  @override
  String get proHavePro => 'BẠN ĐÃ CÓ PRO';

  @override
  String get proWaiting => 'ĐANG CHỜ CỬA HÀNG';

  @override
  String get proChecking => 'ĐANG KIỂM TRA';

  @override
  String get proUnavailableNow => 'HIỆN CHƯA KHẢ DỤNG';

  @override
  String proGet(String price) {
    return 'MUA PRO  $price';
  }

  @override
  String get proPurchasesOff => 'THIẾT BỊ NÀY ĐÃ TẮT MUA HÀNG';

  @override
  String get proPurchaseFailed => 'Giao dịch không thành công.';

  @override
  String get proFeatureImportTitle => 'NHẬP ÂM THANH CỦA BẠN';

  @override
  String get proFeatureImportDetail =>
      'Bất kỳ break nào, bất kỳ one shot nào, từ Files, iCloud, Drive hay một tin nhắn. Cắt gọn, gõ tempo, băm nhỏ.';

  @override
  String get proFeatureMidiTitle => 'XUẤT MIDI VÀ SLICES';

  @override
  String get proFeatureMidiDetail =>
      'Beat dưới dạng tệp MIDI cùng các sample mà nó chơi, ánh xạ sẵn để thả thẳng vào Kong hoặc NN-XT.';

  @override
  String get proFeaturePacksTitle => 'GÓI SLICE';

  @override
  String get proFeaturePacksDetail =>
      'Break và kit làm riêng cho việc này, ra tới đâu có tới đó.';

  @override
  String get proFreeBundled => 'Toàn bộ break và kit đi kèm';

  @override
  String get proFreeMachines => 'Cả hai máy, toàn bộ lưới, làn sub';

  @override
  String get proFreeSongs => 'Bài và xuất WAV';

  @override
  String get proFreeNoAds => 'Không quảng cáo, không bao giờ';
}
