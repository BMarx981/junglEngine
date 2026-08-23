import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:junglengine/features/pro/entitlement_store.dart';
import 'package:junglengine/features/pro/pro_controller.dart';
import 'package:junglengine/features/pro/pro_state.dart';

import '../support/fake_pro_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FakeProStore store;
  ProviderContainer? container;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('junglengine-pro');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => tempDir.path,
        );
    store = FakeProStore();
  });

  tearDown(() {
    store.dispose();
    container?.dispose();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Builds the container, which is what starts the controller talking to the
  /// store. Called by each test after it has said what kind of store this is.
  ProviderContainer open([FakeProStore? using]) {
    final built = ProviderContainer.test(
      overrides: [proStoreProvider.overrideWithValue(using ?? store)],
    );
    built.listen(proProvider, (_, _) {});
    return container = built;
  }

  /// Lets the controller's boot, and any purchase it is chewing on, finish.
  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Opens the container and lets it finish talking to the store.
  Future<void> ready([FakeProStore? using]) async {
    open(using);
    await settle();
  }

  ProState state() => container!.read(proProvider);
  ProController controller() => container!.read(proProvider.notifier);

  test('starts checking, and nothing is unlocked while it is', () {
    open();
    expect(state().phase, ProPhase.checking);
    expect(state().isPro, isFalse);
    expect(state().canBuy, isFalse);
  });

  test("a store with the product ends up locked, with a price", () async {
    open();
    await settle();
    expect(state().phase, ProPhase.locked);
    expect(state().price, '£8.99');
    expect(state().canBuy, isTrue);
  });

  test('a store that does not know the product offers no button', () async {
    store.priceLabel = null;
    open();
    await settle();
    expect(state().phase, ProPhase.locked);
    expect(state().canBuy, isFalse);
  });

  test('a device with purchases turned off says so', () async {
    store.available = false;
    open();
    await settle();
    expect(state().phase, ProPhase.unavailable);
    expect(state().isPro, isFalse);
  });

  group('buying', () {
    test('a purchase unlocks Pro and is completed at the store', () async {
      await ready();
      await controller().buy();
      expect(store.buyCount, 1);
      expect(state().phase, ProPhase.buying);

      store.send(PurchaseStatus.purchased);
      await settle();

      expect(state().isPro, isTrue);
      expect(
        store.completed,
        hasLength(1),
        reason: 'an uncompleted purchase comes back on every launch',
      );
    });

    test('a pending purchase waits rather than unlocking', () async {
      await ready();
      store.send(PurchaseStatus.pending, needsCompleting: false);
      await settle();
      expect(state().phase, ProPhase.buying);
      expect(state().isPro, isFalse);
    });

    test('backing out is not an error', () async {
      await ready();
      await controller().buy();
      store.send(PurchaseStatus.canceled, needsCompleting: false);
      await settle();
      expect(state().phase, ProPhase.locked);
      expect(state().message, isNull);
    });

    test('a refused purchase says why and stays locked', () async {
      await ready();
      store.send(
        PurchaseStatus.error,
        needsCompleting: false,
        error: 'Your card was declined.',
      );
      await settle();
      expect(state().phase, ProPhase.locked);
      expect(state().message, 'Your card was declined.');
    });

    test('a buy the store refuses outright comes back to locked', () async {
      store.buyFails = true;
      await ready();
      await controller().buy();
      await settle();
      expect(state().phase, ProPhase.locked);
      expect(state().message, isNotNull);
    });

    test('a purchase of something else unlocks nothing', () async {
      await ready();
      store.send(PurchaseStatus.purchased, productId: 'some.other.product');
      await settle();

      expect(state().isPro, isFalse);
      expect(
        store.completed,
        isEmpty,
        reason: 'someone else owns that transaction',
      );
    });
  });

  group('restoring', () {
    test('a restored purchase unlocks Pro', () async {
      await ready();
      await controller().restore();
      expect(store.restoreCount, 1);

      store.send(PurchaseStatus.restored);
      await settle();
      expect(state().isPro, isTrue);
    });

    test('a restore that finds nothing is not an error', () async {
      await ready();
      await controller().restore();
      await settle();
      expect(state().phase, ProPhase.locked);
      expect(state().message, isNull);
    });
  });

  group('across a restart', () {
    test('Pro is remembered, so a cold start offline is still Pro', () async {
      await ready();
      store.send(PurchaseStatus.purchased);
      await settle();
      expect(await const EntitlementStore().read(), isTrue);

      // A cold start with no store to ask: on a plane, or with billing down.
      container!.dispose();
      final offline = FakeProStore(available: false);
      addTearDown(offline.dispose);
      await ready(offline);

      expect(state().isPro, isTrue);
    });

    test('a free user with no cache is locked, not unlocked', () async {
      await ready();
      expect(await const EntitlementStore().read(), isFalse);
      expect(state().isPro, isFalse);
    });
  });
}
