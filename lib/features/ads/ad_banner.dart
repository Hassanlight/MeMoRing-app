/// A fail-safe AdMob banner. Renders nothing (zero height) whenever ads can't
/// load — offline, no fill, or devices without Google services (Huawei), so the
/// app never depends on ads to function. Never used on the alert screen.
/// Before the first ad, Google's UMP consent flow runs (shows a consent form
/// only where required, e.g. EEA/UK) — a Play-policy requirement. Fail-open:
/// consent problems never block the app, only that ad load.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:memoring/core/remote_config.dart';

/// Google's public TEST banner unit. Replace with your real AdMob unit id
/// before store release (and swap the APPLICATION_ID in the manifest).
const String kBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

bool _adsInitialized = false;
bool _consentGathered = false;

/// Runs Google's UMP consent flow once per app run. Shows the consent form
/// only where legally required; everywhere else it returns immediately.
Future<void> _gatherConsent() async {
  if (_consentGathered) return;
  final done = Completer<void>();
  ConsentInformation.instance.requestConsentInfoUpdate(
    ConsentRequestParameters(),
    () => ConsentForm.loadAndShowConsentFormIfRequired((_) {
      if (!done.isCompleted) done.complete();
    }),
    (_) {
      if (!done.isCompleted) done.complete();
    },
  );
  await done.future.timeout(const Duration(seconds: 20));
  _consentGathered = true;
}

class AdBanner extends StatefulWidget {
  const AdBanner({this.onUnavailable, super.key});

  /// Called once if AdMob cannot serve here (e.g. Huawei device without
  /// Google services) — lets the host screen fall back to Huawei ads.
  final VoidCallback? onUnavailable;

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _reportedUnavailable = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _unavailable() {
    if (_reportedUnavailable) return;
    _reportedUnavailable = true;
    widget.onUnavailable?.call();
  }

  Future<void> _load() async {
    // Owner master switch — if ads are turned off remotely, show nothing and
    // don't fall back to Huawei ads either.
    if (!RemoteConfig.adsEnabled) {
      if (mounted) setState(() => _loaded = false);
      return;
    }
    try {
      if (!_adsInitialized) {
        try {
          await _gatherConsent();
        } on Object {
          // Consent flow unavailable/timed out → proceed; UMP only gates
          // regions that require the form, and it retries next app run.
        }
        await MobileAds.instance.initialize();
        _adsInitialized = true;
      }
      final ad = BannerAd(
        adUnitId: kBannerAdUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            if (mounted) setState(() => _loaded = true);
          },
          onAdFailedToLoad: (ad, _) {
            ad.dispose();
            if (mounted) setState(() => _loaded = false);
            _unavailable();
          },
        ),
      );
      _ad = ad;
      await ad.load();
    } on Object {
      // No Google services (e.g. Huawei) or other init failure → no banner.
      if (mounted) setState(() => _loaded = false);
      _unavailable();
    }
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
