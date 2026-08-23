import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fil.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ht.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('es'),
    Locale('fil'),
    Locale('fr'),
    Locale('ht'),
    Locale('ja'),
    Locale('ko'),
    Locale('pt'),
    Locale('ru'),
    Locale('vi'),
    Locale('zh'),
  ];

  /// The app name. A wordmark: do not translate or transliterate in any locale.
  ///
  /// In en, this message translates to:
  /// **'junglEngine'**
  String get appTitle;

  /// A count of musical bars, in the uppercase label register used across the app chrome. Appears in the transport bar, the song view, the beat bar and the library. Fits about 12 characters.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 BAR} other{{count} BARS}}'**
  String barCount(int count);

  /// The same count of musical bars in the sentence case register used for body copy under the export options. Keep this consistent with barCount; the only difference is capitalisation. In languages without letter case the two are identical.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 bar} other{{count} bars}}'**
  String barCountSentence(int count);

  /// Just the unit BAR or BARS with no number, because the number is drawn separately and much larger beneath it. Used on the length chips when creating a beat. Fits 6 characters.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{BAR} other{BARS}}'**
  String barUnit(int count);

  /// A count of cards in the song arrangement. A card is one entry in the arrangement list. Uppercase label register. Fits about 12 characters.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 CARD} other{{count} CARDS}}'**
  String cardCount(int count);

  /// Names a beat, where the name is a short generated identifier like A, B or C2. Uppercase label register.
  ///
  /// In en, this message translates to:
  /// **'BEAT {name}'**
  String beatLabel(String name);

  /// Shown centred on screen while the audio for the drum break loads at startup. A break is a sampled drum loop. Uppercase label register.
  ///
  /// In en, this message translates to:
  /// **'LOADING BREAK'**
  String get studioLoadingBreak;

  /// Shown centred on screen when audio could not start at all, which means the app cannot be used. Uppercase label register.
  ///
  /// In en, this message translates to:
  /// **'AUDIO ENGINE FAILED'**
  String get studioEngineFailed;

  /// Button that erases the pattern currently on screen. Top right of the transport bar. Fits 8 characters.
  ///
  /// In en, this message translates to:
  /// **'CLEAR'**
  String get transportClear;

  /// Small heading over a bar count, shown while the song arrangement is open. Fits 12 characters.
  ///
  /// In en, this message translates to:
  /// **'ARRANGEMENT'**
  String get transportArrangement;

  /// Legend to the left of the numbered bar buttons that page through a multi bar pattern. Very tight: fits 4 characters.
  ///
  /// In en, this message translates to:
  /// **'BAR'**
  String get barStripLabel;

  /// Button that appends the open beat to the song arrangement, where name is a short identifier like A or B. Fits 10 characters including the name.
  ///
  /// In en, this message translates to:
  /// **'ADD {name}'**
  String actionAddBeat(String name);

  /// Button that randomly rearranges the slices on the grid. The signature action of the app. One of five buttons sharing the screen width, so it must be short: 9 characters.
  ///
  /// In en, this message translates to:
  /// **'SCRAMBLE'**
  String get actionScramble;

  /// Button that reverts the last scramble. One of five buttons sharing the screen width. Fits 7 characters.
  ///
  /// In en, this message translates to:
  /// **'UNDO'**
  String get actionUndo;

  /// Button that opens the export options. One of five buttons sharing the screen width. Fits 8 characters.
  ///
  /// In en, this message translates to:
  /// **'EXPORT'**
  String get actionExport;

  /// Button that switches from the pattern grid to the song arrangement. Fits 7 characters.
  ///
  /// In en, this message translates to:
  /// **'SONG'**
  String get beatBarSong;

  /// Button that switches from the song arrangement back to the pattern grid. Fits 7 characters.
  ///
  /// In en, this message translates to:
  /// **'GRID'**
  String get beatBarGrid;

  /// Button that duplicates the open beat. Deliberately abbreviated from duplicate because the button is tiny: 5 characters maximum.
  ///
  /// In en, this message translates to:
  /// **'DUP'**
  String get beatBarDup;

  /// Button that creates a new beat. Fits 5 characters.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get beatBarNew;

  /// Confirmation button that deletes the beat the user is holding. Uppercase label register.
  ///
  /// In en, this message translates to:
  /// **'DELETE BEAT'**
  String get beatBarDelete;

  /// Heading of the sheet for creating a beat. A beat is one pattern in the project.
  ///
  /// In en, this message translates to:
  /// **'NEW BEAT'**
  String get newBeatTitle;

  /// Heading over the choice of machine type for a new beat. Machine here means the kind of instrument: a break resequencer or a drum machine.
  ///
  /// In en, this message translates to:
  /// **'MACHINE'**
  String get newBeatMachine;

  /// Explains the CHOP machine, under its name. Break means the sampled drum loop. Keep CHOP itself in English; it is not in this string. Fits about 22 characters.
  ///
  /// In en, this message translates to:
  /// **'RESEQUENCE THE BREAK'**
  String get newBeatChopDetail;

  /// Explains the KIT machine, under its name. A one shot is a single drum sample triggered once, not looped. Fits about 22 characters.
  ///
  /// In en, this message translates to:
  /// **'EIGHT ONE SHOTS'**
  String get newBeatKitDetail;

  /// Heading over the choice of how many bars long the new beat is.
  ///
  /// In en, this message translates to:
  /// **'LENGTH'**
  String get newBeatLength;

  /// Button that confirms creating the new beat.
  ///
  /// In en, this message translates to:
  /// **'CREATE'**
  String get newBeatCreate;

  /// Heading of the song arrangement view.
  ///
  /// In en, this message translates to:
  /// **'SONG'**
  String get songTitle;

  /// Shown in the middle of an empty song arrangement, explaining how to start one. The blank line between the two sentences must be preserved. This string is allowed to wrap onto several lines.
  ///
  /// In en, this message translates to:
  /// **'NOTHING ARRANGED YET\n\nADD THE BEAT YOU HAVE OPEN FROM THE BAR BELOW, THEN SET HOW MANY TIMES IT REPEATS'**
  String get songEmpty;

  /// Heading over the list of drum breaks to choose from. A break is a sampled drum loop.
  ///
  /// In en, this message translates to:
  /// **'BREAK'**
  String get libraryBreak;

  /// Marks the break the user imported themselves, as opposed to the ones bundled with the app. Fits 8 characters.
  ///
  /// In en, this message translates to:
  /// **'YOURS'**
  String get libraryYours;

  /// Button to import an audio file as a break, shown when the user has not imported one yet.
  ///
  /// In en, this message translates to:
  /// **'IMPORT YOUR OWN'**
  String get libraryImportFirst;

  /// Button to import an audio file as a break, shown when the user already has one imported.
  ///
  /// In en, this message translates to:
  /// **'IMPORT ANOTHER'**
  String get libraryImportAnother;

  /// Explains at the foot of the library sheet that a project holds a single break and a single kit, and that swapping the break does not destroy the user's work. Keep KIT in English. This string is allowed to wrap.
  ///
  /// In en, this message translates to:
  /// **'ONE BREAK AND ONE KIT PER PROJECT. CHANGING THE BREAK KEEPS YOUR PATTERNS.'**
  String get libraryNote;

  /// Heading of the export sheet when exporting audio. Keep WAV in English: it is a file format.
  ///
  /// In en, this message translates to:
  /// **'EXPORT WAV'**
  String get exportTitleWav;

  /// Heading of the export sheet when exporting the separate parts, meaning a MIDI file plus the individual samples, rather than one mixed audio file.
  ///
  /// In en, this message translates to:
  /// **'EXPORT PARTS'**
  String get exportTitleParts;

  /// Export option: render the open beat looping. Fits 8 characters.
  ///
  /// In en, this message translates to:
  /// **'LOOP'**
  String get exportModeLoop;

  /// Export option: render the whole song arrangement. Fits 8 characters.
  ///
  /// In en, this message translates to:
  /// **'SONG'**
  String get exportModeSong;

  /// Export option: render a MIDI file plus the samples, rather than mixed audio. Fits 8 characters.
  ///
  /// In en, this message translates to:
  /// **'PARTS'**
  String get exportModeParts;

  /// Detail under the PARTS export option naming what it produces. Keep MIDI in English. Slices are the pieces the break was cut into.
  ///
  /// In en, this message translates to:
  /// **'MIDI + SLICES'**
  String get exportMidiSlices;

  /// Shown as the detail under the SONG export option when the arrangement is empty, so there is nothing to export.
  ///
  /// In en, this message translates to:
  /// **'NOTHING ARRANGED'**
  String get exportNothingArranged;

  /// Heading over the choice of how many times the loop repeats in the exported file.
  ///
  /// In en, this message translates to:
  /// **'REPEATS'**
  String get exportRepeats;

  /// Main button that renders the audio and opens the system share sheet.
  ///
  /// In en, this message translates to:
  /// **'RENDER AND SHARE'**
  String get exportRender;

  /// Main button that builds the MIDI and samples archive and opens the system share sheet.
  ///
  /// In en, this message translates to:
  /// **'BUILD AND SHARE'**
  String get exportBuild;

  /// Body copy describing what the song export will produce. Sentence case, not uppercase. The bars placeholder already contains its number and unit. Keep BPM, kHz and bit in English: they are technical units.
  ///
  /// In en, this message translates to:
  /// **'The whole arrangement, {bars} at {bpm} BPM, 44.1 kHz 16 bit'**
  String exportSongDetail(String bars, int bpm);

  /// Body copy describing what the loop export will produce. Sentence case. The bars placeholder already contains its number and unit. Keep BPM, kHz and bit in English.
  ///
  /// In en, this message translates to:
  /// **'{bars} at {bpm} BPM, 44.1 kHz 16 bit'**
  String exportLoopDetail(String bars, int bpm);

  /// Body copy describing what the parts export will produce. Sentence case. Keep MIDI, Kong and NN-XT in English: Kong and NN-XT are names of samplers in the music program Reason. The note placeholder is a MIDI note number, so it is a bare number like 36.
  ///
  /// In en, this message translates to:
  /// **'Beat {name} as a MIDI file and the {content} it plays, mapped from note {note} for Kong and NN-XT'**
  String exportPartsDetail(String name, String content, int note);

  /// Substituted into exportPartsDetail as the content placeholder when the beat uses the drum machine, giving 'and the kit it plays'. Sentence case, lowercase inside a sentence.
  ///
  /// In en, this message translates to:
  /// **'kit'**
  String get exportPartsKit;

  /// Substituted into exportPartsDetail as the content placeholder when the beat uses the break resequencer, giving 'and the slices it plays'. Sentence case, lowercase inside a sentence.
  ///
  /// In en, this message translates to:
  /// **'slices'**
  String get exportPartsSlices;

  /// Brief message shown in a toast when rendering or sharing did not work. Sentence case.
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get exportFailed;

  /// Heading of the sheet for editing one step of the pattern, where number counts from 1. A step is one cell in the sequencer grid.
  ///
  /// In en, this message translates to:
  /// **'STEP {number}'**
  String stepModStep(int number);

  /// Shown under the step heading when that step has nothing on it.
  ///
  /// In en, this message translates to:
  /// **'EMPTY'**
  String get stepModEmpty;

  /// The default step treatment: play the slice normally, with none of the four effects applied. Fits about 10 characters.
  ///
  /// In en, this message translates to:
  /// **'PLAIN'**
  String get stepModPlain;

  /// Step treatment that plays the slice backwards. Fits about 10 characters.
  ///
  /// In en, this message translates to:
  /// **'REVERSE'**
  String get stepModReverse;

  /// Step treatment that retriggers the slice several times rapidly within the step, a stutter. Abbreviated from retrigger. Fits about 10 characters.
  ///
  /// In en, this message translates to:
  /// **'RETRIG'**
  String get stepModRetrig;

  /// Step treatment that lowers the pitch of the slice. Fits about 12 characters.
  ///
  /// In en, this message translates to:
  /// **'PITCH DOWN'**
  String get stepModPitchDown;

  /// Step treatment that plays the slice at half speed, which also lowers its pitch. Fits about 12 characters.
  ///
  /// In en, this message translates to:
  /// **'HALF SPEED'**
  String get stepModHalfSpeed;

  /// Hint above the drum machine grid telling the user that a long press on a pad opens its settings. Keep VOL and PITCH in English: they label the two controls it opens, which stay in English. A pad is one drum sound's row.
  ///
  /// In en, this message translates to:
  /// **'HOLD A PAD FOR VOL AND PITCH'**
  String get kitHint;

  /// Heading of the sheet for one drum machine slot, where number counts from 1. A slot holds one drum sample.
  ///
  /// In en, this message translates to:
  /// **'SLOT {number}'**
  String kitSlot(int number);

  /// Button to import the user's own audio file into this drum slot. A one shot is a single drum sample triggered once, not looped.
  ///
  /// In en, this message translates to:
  /// **'IMPORT ONE SHOT'**
  String get kitImportOneShot;

  /// The same button when the user has not bought Pro, so pressing it opens the paywall. Keep PRO in English: it is the product name. The double space before the bracket is intentional.
  ///
  /// In en, this message translates to:
  /// **'IMPORT ONE SHOT  (PRO)'**
  String get kitImportOneShotPro;

  /// Button to swap the sample already in this drum slot for a different imported one.
  ///
  /// In en, this message translates to:
  /// **'REPLACE'**
  String get kitReplace;

  /// Button that reverts this slot to the sample that came with the bundled kit, discarding the imported one.
  ///
  /// In en, this message translates to:
  /// **'USE KIT SAMPLE'**
  String get kitUseKitSample;

  /// Heading of the bass synthesiser panel. Sub is short for sub bass, the very low bass line. Keep SUB in English: it labels the lane elsewhere in the app.
  ///
  /// In en, this message translates to:
  /// **'SUB SYNTH'**
  String get subTitle;

  /// Button that erases every bass note. A lane is the horizontal track the notes sit in.
  ///
  /// In en, this message translates to:
  /// **'CLEAR LANE'**
  String get subClearLane;

  /// Hint above the bass lane: dragging a column changes the note's pitch, and holding it adds an accent, which is a louder and brighter note. Keep PITCH in English. Very tight, fits about 24 characters.
  ///
  /// In en, this message translates to:
  /// **'DRAG PITCH HOLD ACCENT'**
  String get subHint;

  /// Heading of the screen for turning an imported audio file into a usable drum break.
  ///
  /// In en, this message translates to:
  /// **'IMPORT BREAK'**
  String get importTitle;

  /// Heading over the control for how many musical bars long the imported audio is. Fits 8 characters.
  ///
  /// In en, this message translates to:
  /// **'BARS'**
  String get importBars;

  /// Heading over the tempo controls for the imported audio. Fits 8 characters.
  ///
  /// In en, this message translates to:
  /// **'TEMPO'**
  String get importTempo;

  /// Button that plays the trimmed audio round in a loop so the user can check the trim is right.
  ///
  /// In en, this message translates to:
  /// **'PREVIEW LOOP'**
  String get importPreviewLoop;

  /// Button that stops the preview playback. Replaces PREVIEW LOOP while playing.
  ///
  /// In en, this message translates to:
  /// **'STOP'**
  String get importStop;

  /// Button the user taps in time with the music to set the tempo. Fits 10 characters.
  ///
  /// In en, this message translates to:
  /// **'TAP'**
  String get importTap;

  /// The tap tempo button once tapping has started, showing how many taps have been counted so far. Fits 10 characters including the number.
  ///
  /// In en, this message translates to:
  /// **'TAP {count}'**
  String importTapCount(int count);

  /// Button that accepts the imported audio and loads it into the project as the break.
  ///
  /// In en, this message translates to:
  /// **'USE THIS BREAK'**
  String get importUseBreak;

  /// Warning shown when the chosen bar count produces an implausible tempo, which usually means the user picked the wrong number of bars. The bars placeholder already contains its number and unit. Keep BPM in English.
  ///
  /// In en, this message translates to:
  /// **'THAT IS {bpm} BPM AT {bars}. TRY A DIFFERENT BAR COUNT.'**
  String importTooFast(int bpm, String bars);

  /// Warning that the imported audio exceeded the maximum length the app accepts, so only the beginning was kept. This string is allowed to wrap.
  ///
  /// In en, this message translates to:
  /// **'THAT FILE WAS LONGER THAN THE IMPORT LIMIT AND WAS CUT SHORT.'**
  String get importTruncated;

  /// Brief message shown in a toast when importing an audio file did not work. Sentence case.
  ///
  /// In en, this message translates to:
  /// **'Import failed'**
  String get importFailed;

  /// Error shown when the system file browser would not open, so the user cannot choose a file. Sentence case.
  ///
  /// In en, this message translates to:
  /// **'Could not open the file picker.'**
  String get importErrorPicker;

  /// Error shown when the chosen file is not audio the app can read, for example a damaged or unsupported format. Sentence case.
  ///
  /// In en, this message translates to:
  /// **'That file would not decode.'**
  String get importErrorDecode;

  /// Error shown when the chosen audio is too brief to cut into slices. Chop means to cut into pieces. Sentence case.
  ///
  /// In en, this message translates to:
  /// **'That file is too short to chop.'**
  String get importErrorTooShort;

  /// Heading of the purchase screen. Both words are the product name: do not translate. Present only so the app name can be cased consistently.
  ///
  /// In en, this message translates to:
  /// **'JUNGLENGINE PRO'**
  String get proTitle;

  /// Sits under the Pro heading and promises a single payment rather than a recurring one, and no advertising. Three short sentences.
  ///
  /// In en, this message translates to:
  /// **'ONE PURCHASE. NO SUBSCRIPTION. NO ADS.'**
  String get proTagline;

  /// Heading over the list of features that are not behind the paywall and never will be. The tone is a reassurance, not a sales pitch.
  ///
  /// In en, this message translates to:
  /// **'ALREADY FREE, AND STAYING FREE'**
  String get proFreeHeader;

  /// Button that recovers a purchase the user already made, for example on a new device. This is standard app store wording: match the platform's usual phrasing in your language.
  ///
  /// In en, this message translates to:
  /// **'RESTORE PURCHASE'**
  String get proRestore;

  /// Developer only button, never visible in a released build. Translating it is optional.
  ///
  /// In en, this message translates to:
  /// **'DEBUG: UNLOCK WITHOUT BUYING'**
  String get proDebugUnlock;

  /// State of the purchase button once the user owns Pro. Keep PRO in English: it is the product name.
  ///
  /// In en, this message translates to:
  /// **'YOU HAVE PRO'**
  String get proHavePro;

  /// State of the purchase button while the app store processes the payment. Store means the platform's app store.
  ///
  /// In en, this message translates to:
  /// **'WAITING FOR THE STORE'**
  String get proWaiting;

  /// State of the purchase button while the app verifies what the user owns.
  ///
  /// In en, this message translates to:
  /// **'CHECKING'**
  String get proChecking;

  /// State of the purchase button when the app store did not return a price, so buying cannot be attempted.
  ///
  /// In en, this message translates to:
  /// **'NOT AVAILABLE RIGHT NOW'**
  String get proUnavailableNow;

  /// The purchase button in its normal state. The price arrives already formatted and localised by the app store, so leave it alone. Keep PRO in English. The double space is intentional.
  ///
  /// In en, this message translates to:
  /// **'GET PRO  {price}'**
  String proGet(String price);

  /// State of the purchase button when in app purchases are disabled on the device, for example by parental controls.
  ///
  /// In en, this message translates to:
  /// **'PURCHASES ARE OFF ON THIS DEVICE'**
  String get proPurchasesOff;

  /// Shown under the purchase button when the payment failed for a reason the store did not explain. Sentence case.
  ///
  /// In en, this message translates to:
  /// **'The purchase did not go through.'**
  String get proPurchaseFailed;

  /// Name of the first Pro feature: bringing in the user's own sound files.
  ///
  /// In en, this message translates to:
  /// **'IMPORT YOUR OWN AUDIO'**
  String get proFeatureImportTitle;

  /// Describes the import feature. Sentence case. Files, iCloud and Drive are product names: keep them in English. A break is a drum loop, a one shot is a single drum sample. Chop means cut into slices.
  ///
  /// In en, this message translates to:
  /// **'Any break, any one shot, from Files, iCloud, Drive or a message. Trim it, tap the tempo, chop it.'**
  String get proFeatureImportDetail;

  /// Name of the second Pro feature. Keep MIDI in English. Slices are the pieces the break was cut into.
  ///
  /// In en, this message translates to:
  /// **'MIDI AND SLICES EXPORT'**
  String get proFeatureMidiTitle;

  /// Describes the MIDI export feature. Sentence case. Keep MIDI, Kong and NN-XT in English: Kong and NN-XT are samplers in the music program Reason.
  ///
  /// In en, this message translates to:
  /// **'The beat as a MIDI file and the samples it plays, mapped to drop straight into Kong or NN-XT.'**
  String get proFeatureMidiDetail;

  /// Name of the third Pro feature: collections of breaks and drum kits sold or included later.
  ///
  /// In en, this message translates to:
  /// **'SLICE PACKS'**
  String get proFeaturePacksTitle;

  /// Describes the slice packs feature. Sentence case. 'As they land' means as they are released over time; it is deliberately casual.
  ///
  /// In en, this message translates to:
  /// **'Breaks and kits made for this, as they land.'**
  String get proFeaturePacksDetail;

  /// One item in the list of things that stay free. Bundled means shipped with the app. Sentence case.
  ///
  /// In en, this message translates to:
  /// **'Every bundled break and kit'**
  String get proFreeBundled;

  /// One item in the list of things that stay free. The two machines are the break resequencer and the drum machine; the sub lane is the bass track. Sentence case.
  ///
  /// In en, this message translates to:
  /// **'Both machines, the whole grid, the sub lane'**
  String get proFreeMachines;

  /// One item in the list of things that stay free. Keep WAV in English: it is a file format. Sentence case.
  ///
  /// In en, this message translates to:
  /// **'Songs and WAV export'**
  String get proFreeSongs;

  /// One item in the list of things that stay free. Ads means advertising. Sentence case.
  ///
  /// In en, this message translates to:
  /// **'No ads, ever'**
  String get proFreeNoAds;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'en',
    'es',
    'fil',
    'fr',
    'ht',
    'ja',
    'ko',
    'pt',
    'ru',
    'vi',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fil':
      return AppLocalizationsFil();
    case 'fr':
      return AppLocalizationsFr();
    case 'ht':
      return AppLocalizationsHt();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
