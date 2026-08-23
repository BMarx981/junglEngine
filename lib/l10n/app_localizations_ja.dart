// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'junglEngine';

  @override
  String barCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count小節',
    );
    return '$_temp0';
  }

  @override
  String barCountSentence(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count小節',
    );
    return '$_temp0';
  }

  @override
  String barUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '小節',
    );
    return '$_temp0';
  }

  @override
  String cardCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count枚',
    );
    return '$_temp0';
  }

  @override
  String beatLabel(String name) {
    return 'ビート $name';
  }

  @override
  String get studioLoadingBreak => 'ブレイクを読み込み中';

  @override
  String get studioEngineFailed => 'オーディオエンジンの起動に失敗';

  @override
  String get transportClear => 'クリア';

  @override
  String get transportArrangement => 'アレンジ';

  @override
  String get barStripLabel => '小節';

  @override
  String actionAddBeat(String name) {
    return '$name を追加';
  }

  @override
  String get actionScramble => 'スクランブル';

  @override
  String get actionUndo => '元に戻す';

  @override
  String get actionExport => '書き出し';

  @override
  String get beatBarSong => 'ソング';

  @override
  String get beatBarGrid => 'グリッド';

  @override
  String get beatBarDup => '複製';

  @override
  String get beatBarNew => '新規';

  @override
  String get beatBarDelete => 'ビートを削除';

  @override
  String get newBeatTitle => '新しいビート';

  @override
  String get newBeatMachine => 'マシン';

  @override
  String get newBeatChopDetail => 'ブレイクを組み替える';

  @override
  String get newBeatKitDetail => 'ワンショット8個';

  @override
  String get newBeatLength => '長さ';

  @override
  String get newBeatCreate => '作成';

  @override
  String get songTitle => 'ソング';

  @override
  String get songEmpty => 'まだ何も並んでいません\n\n下のバーから開いているビートを追加して、繰り返す回数を決めてください';

  @override
  String get libraryBreak => 'ブレイク';

  @override
  String get libraryYours => '自分の';

  @override
  String get libraryImportFirst => '自分の音を読み込む';

  @override
  String get libraryImportAnother => '別の音を読み込む';

  @override
  String get libraryNote => '1プロジェクトにブレイク1つとKIT1つ。ブレイクを変えてもパターンは消えません。';

  @override
  String get exportTitleWav => 'WAVで書き出し';

  @override
  String get exportTitleParts => 'パーツを書き出し';

  @override
  String get exportModeLoop => 'ループ';

  @override
  String get exportModeSong => 'ソング';

  @override
  String get exportModeParts => 'パーツ';

  @override
  String get exportMidiSlices => 'MIDI + SLICES';

  @override
  String get exportNothingArranged => '何も並んでいません';

  @override
  String get exportRepeats => 'リピート';

  @override
  String get exportRender => '書き出して共有';

  @override
  String get exportBuild => '作成して共有';

  @override
  String exportSongDetail(String bars, int bpm) {
    return 'アレンジ全体、$bars／$bpm BPM、44.1 kHz 16 bit';
  }

  @override
  String exportLoopDetail(String bars, int bpm) {
    return '$bars／$bpm BPM、44.1 kHz 16 bit';
  }

  @override
  String exportPartsDetail(String name, String content, int note) {
    return 'ビート $name のMIDIファイルと、鳴っている$content。ノート $note から並べてあるのでKongやNN-XTにそのまま読み込めます';
  }

  @override
  String get exportPartsKit => 'キット';

  @override
  String get exportPartsSlices => 'スライス';

  @override
  String get exportFailed => '書き出しに失敗しました';

  @override
  String stepModStep(int number) {
    return 'ステップ $number';
  }

  @override
  String get stepModEmpty => '空';

  @override
  String get stepModPlain => 'そのまま';

  @override
  String get stepModReverse => 'リバース';

  @override
  String get stepModRetrig => 'リトリガー';

  @override
  String get stepModPitchDown => 'ピッチダウン';

  @override
  String get stepModHalfSpeed => 'ハーフ';

  @override
  String get kitHint => 'パッドを長押しでVOLとPITCH';

  @override
  String kitSlot(int number) {
    return 'スロット $number';
  }

  @override
  String get kitImportOneShot => 'ワンショットを読み込む';

  @override
  String get kitImportOneShotPro => 'ワンショットを読み込む  (PRO)';

  @override
  String get kitReplace => '差し替え';

  @override
  String get kitUseKitSample => 'キットの音に戻す';

  @override
  String get subTitle => 'SUB シンセ';

  @override
  String get subClearLane => 'レーンを消す';

  @override
  String get subHint => 'ドラッグでPITCH 長押しでアクセント';

  @override
  String get importTitle => 'ブレイクを読み込む';

  @override
  String get importBars => '小節数';

  @override
  String get importTempo => 'テンポ';

  @override
  String get importPreviewLoop => 'ループを試聴';

  @override
  String get importStop => '停止';

  @override
  String get importTap => 'タップ';

  @override
  String importTapCount(int count) {
    return 'タップ $count';
  }

  @override
  String get importUseBreak => 'このブレイクを使う';

  @override
  String importTooFast(int bpm, String bars) {
    return '$barsだと$bpm BPMになります。小節数を変えてみてください。';
  }

  @override
  String get importTruncated => 'このファイルは読み込みの上限を超えていたため、途中で切りました。';

  @override
  String get importFailed => '読み込みに失敗しました';

  @override
  String get importErrorPicker => 'ファイル選択を開けませんでした。';

  @override
  String get importErrorDecode => 'このファイルは読み込めませんでした。';

  @override
  String get importErrorTooShort => 'このファイルは短すぎて刻めません。';

  @override
  String get proTitle => 'JUNGLENGINE PRO';

  @override
  String get proTagline => '買い切り。サブスクなし。広告なし。';

  @override
  String get proFreeHeader => 'すでに無料、これからも無料';

  @override
  String get proRestore => '購入を復元';

  @override
  String get proDebugUnlock => 'DEBUG: 購入せずに解除';

  @override
  String get proHavePro => 'PRO をお持ちです';

  @override
  String get proWaiting => 'ストアの応答待ち';

  @override
  String get proChecking => '確認中';

  @override
  String get proUnavailableNow => '現在利用できません';

  @override
  String proGet(String price) {
    return 'PRO を購入  $price';
  }

  @override
  String get proPurchasesOff => 'この端末では購入が無効です';

  @override
  String get proPurchaseFailed => '購入は完了しませんでした。';

  @override
  String get proFeatureImportTitle => '自分の音を読み込む';

  @override
  String get proFeatureImportDetail =>
      'どんなブレイクでも、どんなワンショットでも、Files、iCloud、Drive、メッセージから。切り出して、テンポをタップして、刻む。';

  @override
  String get proFeatureMidiTitle => 'MIDIとスライスの書き出し';

  @override
  String get proFeatureMidiDetail =>
      'ビートのMIDIファイルと鳴っているサンプル。KongやNN-XTにそのまま放り込める並びで書き出します。';

  @override
  String get proFeaturePacksTitle => 'スライスパック';

  @override
  String get proFeaturePacksDetail => 'このために作ったブレイクとキットを、出るたびに。';

  @override
  String get proFreeBundled => '収録のブレイクとキットすべて';

  @override
  String get proFreeMachines => '両方のマシン、グリッド全体、subレーン';

  @override
  String get proFreeSongs => 'ソングとWAV書き出し';

  @override
  String get proFreeNoAds => '広告は一切なし';
}
