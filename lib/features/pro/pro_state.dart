import 'package:flutter/foundation.dart';

/// The product id, which has to match what is set up in App Store Connect and
/// the Play Console.
///
/// One product, bought once, forever. No subscription, no tiers, no consumables
/// and no ads: see the monetisation shape in CLAUDE.md.
const String proProductId = 'app.hawkstreak.junglengine.pro';

/// What the store has told us so far.
enum ProPhase {
  /// Still asking. Nothing is unlocked and nothing is refused: the paywall
  /// waits rather than lying in either direction.
  checking,

  /// The store answered and this is the free tier.
  locked,

  /// A purchase is in flight, or is waiting on someone else to approve it.
  buying,

  /// Pro.
  unlocked,

  /// No store here: a device with purchases turned off, or a platform this app
  /// does not sell on. Free tier, and the paywall says why rather than offering
  /// a button that cannot work.
  unavailable,
}

@immutable
class ProState {
  const ProState({this.phase = ProPhase.checking, this.price, this.message});

  final ProPhase phase;

  /// The localised price, straight from the store. Never hard coded: the store
  /// knows the currency, the tax and what this costs in Brazil.
  final String? price;

  /// The last thing that went wrong, for the paywall to show.
  final String? message;

  bool get isPro => phase == ProPhase.unlocked;

  /// Whether a buy button should do anything.
  bool get canBuy => phase == ProPhase.locked && price != null;

  bool get isBusy => phase == ProPhase.checking || phase == ProPhase.buying;

  ProState copyWith({
    ProPhase? phase,
    String? price,
    String? message,
    bool clearMessage = false,
  }) => ProState(
    phase: phase ?? this.phase,
    price: price ?? this.price,
    message: clearMessage ? null : (message ?? this.message),
  );
}

/// What Pro adds.
///
/// Listed in one place because it is said in two: the paywall, and the store
/// listing. They must not drift apart.
const List<({String title, String detail})> proFeatures = [
  (
    title: 'IMPORT YOUR OWN AUDIO',
    detail:
        'Any break, any one shot, from Files, iCloud, Drive or a message. '
        'Trim it, tap the tempo, chop it.',
  ),
  (
    title: 'MIDI AND SLICES EXPORT',
    detail:
        'The beat as a MIDI file and the samples it plays, mapped to drop '
        'straight into Kong or NN-XT.',
  ),
  (
    title: 'SLICE PACKS',
    detail: 'Breaks and kits made for this, as they land.',
  ),
];

/// The free tier, said out loud so the paywall can be honest about how much of
/// the app is not behind it.
const List<String> freeFeatures = [
  'Every bundled break and kit',
  'Both machines, the whole grid, the sub lane',
  'Songs and WAV export',
  'No ads, ever',
];
