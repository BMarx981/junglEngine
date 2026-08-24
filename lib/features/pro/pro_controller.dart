import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:junglengine/features/pro/entitlement_store.dart';
import 'package:junglengine/features/pro/pro_state.dart';

/// The store, behind an interface.
///
/// Not for the usual reason. It is here because a test host has no App Store
/// and no Play Billing, and because a paywall is the one screen in this app
/// that cannot be checked by hand on a whim: every path through it needs a
/// purchase, a refusal or a network that is not there.
abstract class ProStore {
  /// Whether purchases can happen at all here.
  Future<bool> isAvailable();

  /// The localised price, or null when the store does not know the product.
  /// That usually means it has not been set up yet, or has not propagated.
  Future<String?> price();

  /// Purchase updates, including ones that arrive unprompted: a purchase
  /// approved by a parent, or one left unfinished by the last session.
  Stream<List<PurchaseDetails>> get purchases;

  Future<void> buy();

  Future<void> restore();

  Future<void> complete(PurchaseDetails purchase);
}

/// The real one.
class IapProStore implements ProStore {
  const IapProStore();

  InAppPurchase get _iap => InAppPurchase.instance;

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<String?> price() async {
    final response = await _iap.queryProductDetails({proProductId});
    for (final product in response.productDetails) {
      if (product.id == proProductId) return product.price;
    }
    return null;
  }

  @override
  Stream<List<PurchaseDetails>> get purchases => _iap.purchaseStream;

  @override
  Future<void> buy() async {
    final response = await _iap.queryProductDetails({proProductId});
    final product = response.productDetails
        .where((p) => p.id == proProductId)
        .firstOrNull;
    if (product == null) {
      throw StateError('the store does not know about $proProductId yet');
    }
    await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
  }

  @override
  Future<void> restore() => _iap.restorePurchases();

  @override
  Future<void> complete(PurchaseDetails purchase) =>
      _iap.completePurchase(purchase);
}

final proStoreProvider = Provider<ProStore>((ref) => const IapProStore());

final entitlementStoreProvider = Provider<EntitlementStore>(
  (ref) => const EntitlementStore(),
);

/// Whether this is Pro, and everything that decides it.
///
/// There is no receipt validation and no server, because there is no server in
/// this app at all. The store's own word plus a local cache is the whole of it,
/// which is the right amount of machinery for a one off unlock on a phone.
class ProController extends Notifier<ProState> {
  StreamSubscription<List<PurchaseDetails>>? _purchases;

  /// How long to wait on a store that is not answering.
  ///
  /// Billing lives behind a platform channel and a network. A device that never
  /// answers must not leave the paywall spinning forever, and must not lock a
  /// user out of what they bought: a timeout falls back to the cache.
  static const Duration _timeout = Duration(seconds: 12);

  ProStore get _store => ref.read(proStoreProvider);

  EntitlementStore get _cache => ref.read(entitlementStoreProvider);

  @override
  ProState build() {
    ref.onDispose(() {
      unawaited(_purchases?.cancel());
      _purchases = null;
    });
    unawaited(_connect());
    return const ProState();
  }

  /// Sets state, unless the provider is gone.
  ///
  /// Everything here is a chain of awaits on a platform channel and a network,
  /// and the app can be closed in the middle of any of them. Writing state
  /// afterwards would throw into nobody's hands.
  void _update(ProState Function(ProState) change) {
    // Reading state is as unsafe as writing it once the provider is gone, so
    // the change is a function rather than a value: nothing touches state
    // until after the guard.
    if (!ref.mounted) return;
    state = change(state);
  }

  Future<void> _connect() async {
    // The cache first, so a Pro user who opens the app offline is Pro before
    // the store has said anything.
    final remembered = await _cache.read();
    if (!ref.mounted) return;
    if (remembered) _update((s) => s.copyWith(phase: ProPhase.unlocked));

    // Subscribed before anything is bought, because the stream also delivers
    // purchases finished outside the app and ones left over from last session.
    _purchases = _store.purchases.listen(
      _onPurchases,
      onError: (Object error) => _update(
        (s) => s.copyWith(failed: true, storeMessage: _storeMessage(error)),
      ),
    );

    final bool available;
    try {
      available = await _store.isAvailable().timeout(_timeout);
    } on Object catch (error) {
      _update(
        (s) => s.copyWith(
          phase: remembered ? ProPhase.unlocked : ProPhase.unavailable,
          failed: true,
          storeMessage: _storeMessage(error),
        ),
      );
      return;
    }
    if (!ref.mounted) return;

    if (!available) {
      _update(
        (s) => s.copyWith(
          phase: remembered ? ProPhase.unlocked : ProPhase.unavailable,
        ),
      );
      return;
    }

    String? price;
    try {
      price = await _store.price().timeout(_timeout);
    } on Object catch (error) {
      debugPrint('junglengine: no price from the store ($error)');
    }

    _update(
      (s) => s.copyWith(
        phase: remembered ? ProPhase.unlocked : ProPhase.locked,
        price: price,
      ),
    );
  }

  /// Buys Pro. The answer arrives on the purchase stream, not from here.
  Future<void> buy() async {
    if (!ref.mounted || !state.canBuy) return;
    _update((s) => s.copyWith(phase: ProPhase.buying, clearMessage: true));
    try {
      await _store.buy();
    } on Object catch (error) {
      _update(
        (s) => s.copyWith(
          phase: ProPhase.locked,
          failed: true,
          storeMessage: _storeMessage(error),
        ),
      );
    }
  }

  /// Asks the store what this account already owns.
  ///
  /// A restore that finds nothing is not an error and must not read as one: the
  /// usual reason is that this account never bought it.
  Future<void> restore() async {
    _update((s) => s.copyWith(clearMessage: true));
    try {
      await _store.restore().timeout(_timeout);
    } on Object catch (error) {
      _update(
        (s) => s.copyWith(failed: true, storeMessage: _storeMessage(error)),
      );
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != proProductId) continue;
      if (!ref.mounted) return;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          _update(
            (s) => s.copyWith(phase: ProPhase.buying, clearMessage: true),
          );
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _unlock();
        case PurchaseStatus.error:
          _update(
            (s) => s.copyWith(
              phase: s.isPro ? ProPhase.unlocked : ProPhase.locked,
              failed: true,
              // Whatever the store said, in the buyer's language. When it said
              // nothing, the paywall supplies its own translated line.
              storeMessage: purchase.error?.message,
            ),
          );
        case PurchaseStatus.canceled:
          // Backing out of a purchase is a decision, not a failure.
          _update(
            (s) => s.copyWith(
              phase: s.isPro ? ProPhase.unlocked : ProPhase.locked,
              clearMessage: true,
            ),
          );
      }

      // Every purchased or restored transaction has to be completed or the
      // store will hand it back on every launch, and on iOS will refuse the
      // next purchase of the same product as a duplicate.
      if (purchase.pendingCompletePurchase) {
        try {
          await _store.complete(purchase);
        } on Object catch (error) {
          debugPrint('junglengine: purchase not completed ($error)');
        }
      }
    }
  }

  Future<void> _unlock() async {
    _update((s) => s.copyWith(phase: ProPhase.unlocked, clearMessage: true));
    await _cache.write(pro: true);
  }

  /// Unlocks without buying anything. Debug builds only.
  ///
  /// The products do not exist in App Store Connect or the Play Console until
  /// someone sets them up, and the Pro features have to be testable before that
  /// day. Compiled out of release: [kDebugMode] is a const.
  Future<void> unlockForTesting() async {
    if (!kDebugMode) return;
    await _unlock();
  }

  /// The store's own wording for a failure, when there is one.
  ///
  /// Null for anything else. A thrown Dart exception carries an untranslated
  /// English string, which belongs in the log rather than on the paywall, so
  /// the paywall falls back to its own translated line instead.
  static String? _storeMessage(Object error) {
    debugPrint('junglengine: purchase error ($error)');
    return error is IAPError ? error.message : null;
  }
}

final proProvider = NotifierProvider<ProController, ProState>(
  ProController.new,
);
