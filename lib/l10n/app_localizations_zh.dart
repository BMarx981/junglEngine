// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'junglEngine';

  @override
  String barCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 小节',
    );
    return '$_temp0';
  }

  @override
  String barCountSentence(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 小节',
    );
    return '$_temp0';
  }

  @override
  String barUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '小节',
    );
    return '$_temp0';
  }

  @override
  String cardCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 张',
    );
    return '$_temp0';
  }

  @override
  String beatLabel(String name) {
    return '节奏 $name';
  }

  @override
  String get studioLoadingBreak => '正在载入鼓点';

  @override
  String get studioEngineFailed => '音频引擎启动失败';

  @override
  String get transportClear => '清空';

  @override
  String get transportArrangement => '编排';

  @override
  String get barStripLabel => '小节';

  @override
  String actionAddBeat(String name) {
    return '添加 $name';
  }

  @override
  String get actionScramble => '打乱';

  @override
  String get actionUndo => '撤销';

  @override
  String get actionExport => '导出';

  @override
  String get beatBarSong => '歌曲';

  @override
  String get beatBarGrid => '网格';

  @override
  String get beatBarDup => '复制';

  @override
  String get beatBarNew => '新建';

  @override
  String get beatBarDelete => '删除节奏';

  @override
  String get newBeatTitle => '新建节奏';

  @override
  String get newBeatMachine => '机器';

  @override
  String get newBeatChopDetail => '重新排列鼓点';

  @override
  String get newBeatKitDetail => '八个单击音色';

  @override
  String get newBeatLength => '长度';

  @override
  String get newBeatCreate => '创建';

  @override
  String get songTitle => '歌曲';

  @override
  String get songEmpty => '还没有编排任何内容\n\n从下方的条中添加当前打开的节奏，再设定它重复几次';

  @override
  String get libraryBreak => '鼓点';

  @override
  String get libraryYours => '自己的';

  @override
  String get libraryImportFirst => '导入自己的音频';

  @override
  String get libraryImportAnother => '导入另一个';

  @override
  String get libraryNote => '每个项目一段鼓点和一套 KIT。更换鼓点不会清除你的节奏型。';

  @override
  String get exportTitleWav => '导出 WAV';

  @override
  String get exportTitleParts => '导出分轨';

  @override
  String get exportModeLoop => '循环';

  @override
  String get exportModeSong => '歌曲';

  @override
  String get exportModeParts => '分轨';

  @override
  String get exportMidiSlices => 'MIDI + SLICES';

  @override
  String get exportNothingArranged => '尚未编排';

  @override
  String get exportRepeats => '重复次数';

  @override
  String get exportRender => '渲染并分享';

  @override
  String get exportBuild => '生成并分享';

  @override
  String exportSongDetail(String bars, int bpm) {
    return '整段编排，$bars，$bpm BPM，44.1 kHz 16 bit';
  }

  @override
  String exportLoopDetail(String bars, int bpm) {
    return '$bars，$bpm BPM，44.1 kHz 16 bit';
  }

  @override
  String exportPartsDetail(String name, String content, int note) {
    return '节奏 $name 的 MIDI 文件，以及它所播放的$content，从音符 $note 开始映射，可直接导入 Kong 或 NN-XT';
  }

  @override
  String get exportPartsKit => '鼓组';

  @override
  String get exportPartsSlices => '切片';

  @override
  String get exportFailed => '导出失败';

  @override
  String stepModStep(int number) {
    return '第 $number 步';
  }

  @override
  String get stepModEmpty => '空';

  @override
  String get stepModPlain => '原样';

  @override
  String get stepModReverse => '倒放';

  @override
  String get stepModRetrig => '连击';

  @override
  String get stepModPitchDown => '降调';

  @override
  String get stepModHalfSpeed => '半速';

  @override
  String get kitHint => '长按打击垫调整 VOL 和 PITCH';

  @override
  String kitSlot(int number) {
    return '槽位 $number';
  }

  @override
  String get kitImportOneShot => '导入单击音色';

  @override
  String get kitImportOneShotPro => '导入单击音色  (PRO)';

  @override
  String get kitReplace => '替换';

  @override
  String get kitUseKitSample => '恢复鼓组音色';

  @override
  String get subTitle => 'SUB 合成器';

  @override
  String get subClearLane => '清空音轨';

  @override
  String get subHint => '拖动改 PITCH 长按加重音';

  @override
  String get subEdit => '编辑音符';

  @override
  String get subNotesTitle => 'SUB 音符';

  @override
  String get subEditorHint => '点格子放一个音符';

  @override
  String get subAccent => '重音';

  @override
  String get subClearNote => '清除音符';

  @override
  String get subMoveEarlier => '音符前移一步';

  @override
  String get subMoveLater => '音符后移一步';

  @override
  String get importTitle => '导入鼓点';

  @override
  String get importBars => '小节数';

  @override
  String get importTempo => '速度';

  @override
  String get importPreviewLoop => '试听循环';

  @override
  String get importStop => '停止';

  @override
  String get importTap => '打拍';

  @override
  String importTapCount(int count) {
    return '打拍 $count';
  }

  @override
  String get importUseBreak => '使用这段鼓点';

  @override
  String importTooFast(int bpm, String bars) {
    return '按$bars算是 $bpm BPM。换一个小节数试试。';
  }

  @override
  String get importTruncated => '这个文件超过了导入长度上限，已被截断。';

  @override
  String get importFailed => '导入失败';

  @override
  String get importErrorPicker => '无法打开文件选择器。';

  @override
  String get importErrorDecode => '这个文件无法解码。';

  @override
  String get importErrorTooShort => '这个文件太短，无法切片。';

  @override
  String get proTitle => 'JUNGLENGINE PRO';

  @override
  String get proTagline => '一次买断。没有订阅。没有广告。';

  @override
  String get proFreeHeader => '本来就免费，也会一直免费';

  @override
  String get proRestore => '恢复购买';

  @override
  String get proDebugUnlock => 'DEBUG: 不付费直接解锁';

  @override
  String get proHavePro => '你已拥有 PRO';

  @override
  String get proWaiting => '等待商店响应';

  @override
  String get proChecking => '正在检查';

  @override
  String get proUnavailableNow => '暂时无法购买';

  @override
  String proGet(String price) {
    return '获取 PRO  $price';
  }

  @override
  String get proPurchasesOff => '此设备已关闭内购';

  @override
  String get proPurchaseFailed => '购买未完成。';

  @override
  String get proFeatureImportTitle => '导入你自己的音频';

  @override
  String get proFeatureImportDetail =>
      '任何鼓点，任何单击音色，来自 Files、iCloud、Drive 或一条消息。裁剪、打出速度、切片。';

  @override
  String get proFeatureMidiTitle => '导出 MIDI 与切片';

  @override
  String get proFeatureMidiDetail =>
      '节奏的 MIDI 文件和它播放的采样，映射好后可直接放进 Kong 或 NN-XT。';

  @override
  String get proFeaturePacksTitle => '切片包';

  @override
  String get proFeaturePacksDetail => '为这个而做的鼓点和鼓组，陆续推出。';

  @override
  String get proFreeBundled => 'Starter 音色包内的全部内容';

  @override
  String get proFreeMachines => '两台机器、整个网格、sub 音轨';

  @override
  String get proFreeSongs => '歌曲与 WAV 导出';

  @override
  String get proFreeNoAds => '永远没有广告';
}
