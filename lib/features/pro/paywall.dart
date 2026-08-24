import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:junglengine/features/pro/pro_controller.dart';
import 'package:junglengine/features/pro/pro_state.dart';
import 'package:junglengine/l10n/l10n.dart';
import 'package:junglengine/theme.dart';

/// The name and the sentence under it, for one Pro feature.
(String, String) _proFeatureCopy(AppLocalizations l10n, ProFeature feature) =>
    switch (feature) {
      ProFeature.import => (
        l10n.proFeatureImportTitle,
        l10n.proFeatureImportDetail,
      ),
      ProFeature.midi => (l10n.proFeatureMidiTitle, l10n.proFeatureMidiDetail),
      ProFeature.packs => (
        l10n.proFeaturePacksTitle,
        l10n.proFeaturePacksDetail,
      ),
    };

/// One line in the list of things that are free and staying free.
String _freeFeatureCopy(AppLocalizations l10n, FreeFeature feature) =>
    switch (feature) {
      FreeFeature.bundled => l10n.proFreeBundled,
      FreeFeature.machines => l10n.proFreeMachines,
      FreeFeature.songs => l10n.proFreeSongs,
      FreeFeature.noAds => l10n.proFreeNoAds,
    };

/// What Pro costs and what it is.
///
/// Shown at the moment someone reaches for a Pro feature, never on launch and
/// never as an interruption. The free tier is listed alongside, because most of
/// this app is in it and a paywall that hides that is selling badly.
class Paywall extends ConsumerWidget {
  const Paywall({super.key});

  /// Returns true if the user came out of it with Pro.
  static Future<bool> show(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: JungleTheme.surface,
      isScrollControlled: true,
      builder: (_) => const Paywall(),
    );
    if (!context.mounted) return false;
    return ProviderScope.containerOf(context).read(proProvider).isPro;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pro = ref.watch(proProvider);
    final controller = ref.read(proProvider.notifier);
    final labelSmall = Theme.of(context).textTheme.labelSmall;

    // Buying it while looking at it is the one time this closes itself.
    ref.listen(proProvider, (previous, next) {
      if (next.isPro &&
          previous?.isPro != true &&
          Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.proTitle,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            Text(context.l10n.proTagline, style: labelSmall),
            const SizedBox(height: 16),
            for (final (title, detail) in ProFeature.values.map(
              (feature) => _proFeatureCopy(context.l10n, feature),
            )) ...[
              _Feature(title: title, detail: detail),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: JungleTheme.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(context.l10n.proFreeHeader, style: labelSmall),
                  const SizedBox(height: 6),
                  for (final feature in FreeFeature.values.map(
                    (feature) => _freeFeatureCopy(context.l10n, feature),
                  ))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '· $feature',
                        style: const TextStyle(
                          color: JungleTheme.textDim,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buyButton(context, pro, controller),
            if (pro.failed) ...[
              const SizedBox(height: 8),
              Text(
                pro.storeMessage ?? context.l10n.proPurchaseFailed,
                textAlign: TextAlign.center,
                style: labelSmall?.copyWith(color: JungleTheme.hot),
              ),
            ],
            const SizedBox(height: 4),
            TextButton(
              onPressed: pro.isBusy ? null : controller.restore,
              child: Text(context.l10n.proRestore, style: labelSmall),
            ),
            // The products do not exist in the stores until someone sets them
            // up, and the Pro features have to be testable before that day.
            if (kDebugMode)
              TextButton(
                onPressed: controller.unlockForTesting,
                child: Text(
                  context.l10n.proDebugUnlock,
                  style: labelSmall?.copyWith(color: JungleTheme.sub),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buyButton(
    BuildContext context,
    ProState pro,
    ProController controller,
  ) {
    final l10n = context.l10n;
    final label = switch (pro.phase) {
      ProPhase.unlocked => l10n.proHavePro,
      ProPhase.buying => l10n.proWaiting,
      ProPhase.checking => l10n.proChecking,
      // No price means the store does not know the product. Saying so beats a
      // button that fails when it is pressed.
      ProPhase.locked =>
        pro.price == null
            ? l10n.proUnavailableNow
            // The store hands the price over already formatted for the buyer's
            // country, so it is passed through untouched.
            : l10n.proGet(pro.price!),
      ProPhase.unavailable => l10n.proPurchasesOff,
    };

    return SizedBox(
      height: 52,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: JungleTheme.accent,
          foregroundColor: JungleTheme.background,
          disabledBackgroundColor: JungleTheme.surfaceHigh,
          disabledForegroundColor: JungleTheme.textDim,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: pro.canBuy ? controller.buy : null,
        child: pro.phase == ProPhase.buying
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: JungleTheme.textDim,
                ),
              )
            : Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 3,
          height: 34,
          margin: const EdgeInsets.only(top: 2, right: 10),
          color: JungleTheme.accent,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: JungleTheme.text,
                  fontSize: 12,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: const TextStyle(
                  color: JungleTheme.textDim,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
