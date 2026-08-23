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
  const ProState({
    this.phase = ProPhase.checking,
    this.price,
    this.storeMessage,
    this.failed = false,
  });

  final ProPhase phase;

  /// The localised price, straight from the store. Never hard coded: the store
  /// knows the currency, the tax and what this costs in Brazil.
  final String? price;

  /// What the store said went wrong, in the buyer's language.
  ///
  /// Only ever the store's own words. "Your card was declined" is written by
  /// App Store Connect or Play Billing and arrives already translated, so it
  /// is worth showing verbatim. Anything this app would have to word itself
  /// does not belong here: see [failed].
  final String? storeMessage;

  /// Whether the last attempt failed, whatever the store did or did not say.
  ///
  /// Separate from [storeMessage] because most failures arrive as a Dart
  /// exception with an untranslated English string, which is a log line rather
  /// than something to put in front of a buyer. The paywall shows the store's
  /// wording when there is one and its own translated line when there is not.
  final bool failed;

  bool get isPro => phase == ProPhase.unlocked;

  /// Whether a buy button should do anything.
  bool get canBuy => phase == ProPhase.locked && price != null;

  bool get isBusy => phase == ProPhase.checking || phase == ProPhase.buying;

  ProState copyWith({
    ProPhase? phase,
    String? price,
    String? storeMessage,
    bool? failed,
    bool clearMessage = false,
  }) => ProState(
    phase: phase ?? this.phase,
    price: price ?? this.price,
    storeMessage: clearMessage ? null : (storeMessage ?? this.storeMessage),
    failed: clearMessage ? false : (failed ?? this.failed),
  );
}

/// What Pro adds, and what stays free.
///
/// Only the identities live here. The words moved to the ARB files and are
/// assembled in `paywall.dart`, because this is the copy most worth having in
/// a buyer's own language and it cannot be translated from a state file.
///
/// The store listing still has to say the same things as the paywall. That is
/// now a matter of keeping the listing in step with `lib/l10n/app_en.arb`
/// rather than with this list.
enum ProFeature { import, midi, packs }

enum FreeFeature { bundled, machines, songs, noAds }
