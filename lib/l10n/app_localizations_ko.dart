// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'junglEngine';

  @override
  String barCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count마디',
    );
    return '$_temp0';
  }

  @override
  String barCountSentence(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count마디',
    );
    return '$_temp0';
  }

  @override
  String barUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '마디',
    );
    return '$_temp0';
  }

  @override
  String cardCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count장',
    );
    return '$_temp0';
  }

  @override
  String beatLabel(String name) {
    return '비트 $name';
  }

  @override
  String get studioLoadingBreak => '브레이크 불러오는 중';

  @override
  String get studioEngineFailed => '오디오 엔진 실행 실패';

  @override
  String get transportClear => '지우기';

  @override
  String get transportArrangement => '편곡';

  @override
  String get barStripLabel => '마디';

  @override
  String actionAddBeat(String name) {
    return '$name 추가';
  }

  @override
  String get actionScramble => '섞기';

  @override
  String get actionUndo => '되돌리기';

  @override
  String get actionExport => '내보내기';

  @override
  String get beatBarSong => '송';

  @override
  String get beatBarGrid => '그리드';

  @override
  String get beatBarDup => '복제';

  @override
  String get beatBarNew => '새로';

  @override
  String get beatBarDelete => '비트 삭제';

  @override
  String get newBeatTitle => '새 비트';

  @override
  String get newBeatMachine => '머신';

  @override
  String get newBeatChopDetail => '브레이크 재배열';

  @override
  String get newBeatKitDetail => '원샷 여덟 개';

  @override
  String get newBeatLength => '길이';

  @override
  String get newBeatCreate => '만들기';

  @override
  String get songTitle => '송';

  @override
  String get songEmpty =>
      '아직 배치된 것이 없습니다\n\n아래 바에서 열려 있는 비트를 추가하고, 몇 번 반복할지 정하세요';

  @override
  String get libraryBreak => '브레이크';

  @override
  String get libraryYours => '내 것';

  @override
  String get libraryImportFirst => '내 오디오 가져오기';

  @override
  String get libraryImportAnother => '다른 오디오 가져오기';

  @override
  String get libraryNote => '프로젝트마다 브레이크 하나와 KIT 하나. 브레이크를 바꿔도 패턴은 그대로 남습니다.';

  @override
  String get exportTitleWav => 'WAV 내보내기';

  @override
  String get exportTitleParts => '파트 내보내기';

  @override
  String get exportModeLoop => '루프';

  @override
  String get exportModeSong => '송';

  @override
  String get exportModeParts => '파트';

  @override
  String get exportMidiSlices => 'MIDI + SLICES';

  @override
  String get exportNothingArranged => '배치된 것 없음';

  @override
  String get exportRepeats => '반복';

  @override
  String get exportRender => '렌더링 후 공유';

  @override
  String get exportBuild => '생성 후 공유';

  @override
  String exportSongDetail(String bars, int bpm) {
    return '편곡 전체, $bars / $bpm BPM, 44.1 kHz 16 bit';
  }

  @override
  String exportLoopDetail(String bars, int bpm) {
    return '$bars / $bpm BPM, 44.1 kHz 16 bit';
  }

  @override
  String exportPartsDetail(String name, String content, int note) {
    return '비트 $name의 MIDI 파일과 재생되는 $content. 노트 $note부터 매핑되어 Kong이나 NN-XT에 바로 들어갑니다';
  }

  @override
  String get exportPartsKit => '킷';

  @override
  String get exportPartsSlices => '슬라이스';

  @override
  String get exportFailed => '내보내기에 실패했습니다';

  @override
  String stepModStep(int number) {
    return '스텝 $number';
  }

  @override
  String get stepModEmpty => '비어 있음';

  @override
  String get stepModPlain => '그대로';

  @override
  String get stepModReverse => '리버스';

  @override
  String get stepModRetrig => '리트리거';

  @override
  String get stepModPitchDown => '피치 다운';

  @override
  String get stepModHalfSpeed => '하프 스피드';

  @override
  String get kitHint => '패드를 길게 눌러 VOL과 PITCH';

  @override
  String kitSlot(int number) {
    return '슬롯 $number';
  }

  @override
  String get kitImportOneShot => '원샷 가져오기';

  @override
  String get kitImportOneShotPro => '원샷 가져오기  (PRO)';

  @override
  String get kitReplace => '교체';

  @override
  String get kitUseKitSample => '킷 샘플로 되돌리기';

  @override
  String get subTitle => 'SUB 신스';

  @override
  String get subClearLane => '레인 비우기';

  @override
  String get subHint => '드래그로 PITCH 길게 눌러 액센트';

  @override
  String get subEdit => '노트 편집';

  @override
  String get subNotesTitle => 'SUB 노트';

  @override
  String get subEditorHint => '칸을 눌러 노트를 놓으세요';

  @override
  String get subAccent => '액센트';

  @override
  String get subClearNote => '노트 지우기';

  @override
  String get subMoveEarlier => '노트를 한 스텝 앞으로';

  @override
  String get subMoveLater => '노트를 한 스텝 뒤로';

  @override
  String get importTitle => '브레이크 가져오기';

  @override
  String get importBars => '마디';

  @override
  String get importTempo => '템포';

  @override
  String get importPreviewLoop => '루프 미리 듣기';

  @override
  String get importStop => '정지';

  @override
  String get importTap => '탭';

  @override
  String importTapCount(int count) {
    return '탭 $count';
  }

  @override
  String get importUseBreak => '이 브레이크 사용';

  @override
  String importTooFast(int bpm, String bars) {
    return '$bars 기준으로 $bpm BPM입니다. 마디 수를 다르게 해보세요.';
  }

  @override
  String get importTruncated => '이 파일은 가져오기 한도보다 길어서 잘렸습니다.';

  @override
  String get importFailed => '가져오기에 실패했습니다';

  @override
  String get importErrorPicker => '파일 선택 창을 열 수 없습니다.';

  @override
  String get importErrorDecode => '이 파일은 디코딩할 수 없습니다.';

  @override
  String get importErrorTooShort => '이 파일은 너무 짧아서 자를 수 없습니다.';

  @override
  String get proTitle => 'JUNGLENGINE PRO';

  @override
  String get proTagline => '한 번 결제. 구독 없음. 광고 없음.';

  @override
  String get proFreeHeader => '이미 무료이고, 계속 무료입니다';

  @override
  String get proRestore => '구매 복원';

  @override
  String get proDebugUnlock => 'DEBUG: 결제 없이 잠금 해제';

  @override
  String get proHavePro => 'PRO 사용 중';

  @override
  String get proWaiting => '스토어 응답 대기 중';

  @override
  String get proChecking => '확인 중';

  @override
  String get proUnavailableNow => '지금은 사용할 수 없음';

  @override
  String proGet(String price) {
    return 'PRO 구매  $price';
  }

  @override
  String get proPurchasesOff => '이 기기에서는 결제가 꺼져 있습니다';

  @override
  String get proPurchaseFailed => '결제가 완료되지 않았습니다.';

  @override
  String get proFeatureImportTitle => '내 오디오 가져오기';

  @override
  String get proFeatureImportDetail =>
      '어떤 브레이크든, 어떤 원샷이든, Files, iCloud, Drive, 메시지에서. 잘라내고, 템포를 두드리고, 쪼개세요.';

  @override
  String get proFeatureMidiTitle => 'MIDI와 슬라이스 내보내기';

  @override
  String get proFeatureMidiDetail =>
      '비트의 MIDI 파일과 재생되는 샘플을, Kong이나 NN-XT에 바로 얹을 수 있게 매핑해서.';

  @override
  String get proFeaturePacksTitle => '슬라이스 팩';

  @override
  String get proFeaturePacksDetail => '이걸 위해 만든 브레이크와 킷을, 나올 때마다.';

  @override
  String get proFreeBundled => '기본 제공 브레이크와 킷 전부';

  @override
  String get proFreeMachines => '두 머신, 그리드 전체, sub 레인';

  @override
  String get proFreeSongs => '송과 WAV 내보내기';

  @override
  String get proFreeNoAds => '광고는 절대 없음';
}
