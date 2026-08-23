import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:junglengine/features/pro/pro_controller.dart';
import 'package:junglengine/features/pro/pro_state.dart';

/// A store that answers, which is more than a test host's real one does.
///
/// There is no App Store and no Play Billing behind a `flutter test`, so the
/// real [IapProStore] hangs on its first call and leaves a timeout pending at
/// the end of every test. This stands in for it, and lets a test say what the
/// store did: a price, a refusal, a purchase approved half a minute later.
class FakeProStore implements ProStore {
  FakeProStore({
    this.available = true,
    this.priceLabel = '£8.99',
    this.buyFails = false,
  });

  bool available;
  String? priceLabel;

  /// Makes [buy] throw, the way a store does when the product is not set up.
  bool buyFails;

  int buyCount = 0;
  int restoreCount = 0;
  final List<PurchaseDetails> completed = [];

  final StreamController<List<PurchaseDetails>> _purchases =
      StreamController<List<PurchaseDetails>>.broadcast();

  @override
  Stream<List<PurchaseDetails>> get purchases => _purchases.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<String?> price() async => priceLabel;

  @override
  Future<void> buy() async {
    buyCount++;
    if (buyFails) throw StateError('the store does not know that product');
  }

  @override
  Future<void> restore() async => restoreCount++;

  @override
  Future<void> complete(PurchaseDetails purchase) async =>
      completed.add(purchase);

  /// Pushes an update the way the real stream does.
  void send(
    PurchaseStatus status, {
    bool needsCompleting = true,
    String? error,
    String productId = proProductId,
  }) {
    _purchases.add([
      PurchaseDetails(
          productID: productId,
          purchaseID: 'test-purchase',
          verificationData: PurchaseVerificationData(
            localVerificationData: '',
            serverVerificationData: '',
            source: 'test',
          ),
          transactionDate: null,
          status: status,
        )
        ..pendingCompletePurchase = needsCompleting
        ..error = error == null
            ? null
            : IAPError(source: 'test', code: 'test_error', message: error),
    ]);
  }

  void dispose() => _purchases.close();
}
