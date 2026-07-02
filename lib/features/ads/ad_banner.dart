/// A fail-safe AdMob banner. Renders nothing (zero height) whenever ads can't
/// load — offline, no fill, or devices without Google services (Huawei), so the
/// app never depends on ads to function. Never used on the alert screen.
library;

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Google's public TEST banner unit. Replace with your real AdMob unit id
/// before store release (and swap the APPLICATION_ID in the manifest).
const String kBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

bool _adsInitialized = false;

class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (!_adsInitialized) {
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
          },
        ),
      );
      _ad = ad;
      await ad.load();
    } on Object {
      // No Google services (e.g. Huawei) or other init failure → no banner.
      if (mounted) setState(() => _loaded = false);
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
