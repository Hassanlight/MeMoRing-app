/// Huawei (Petal) Ads banner for devices without Google services.
/// Overlay-style banner shown only while the host screen is open; every call is
/// wrapped so non-Huawei devices and tests are completely unaffected.
/// Uses Huawei's PUBLIC TEST slot until a real Petal Ads account exists.
library;

import 'package:huawei_ads/huawei_ads.dart' as hw;

/// Huawei's public test banner slot — replace with your real Petal Ads slot id
/// (AppGallery Connect → Earning → Ads) before expecting revenue.
const String kHuaweiBannerSlotId = 'testw6vs28auh3';

class HuaweiBannerController {
  hw.BannerAd? _ad;
  bool _started = false;

  /// Initializes HMS ads and shows a bottom banner. Safe to call anywhere —
  /// silently does nothing on devices without HMS Core.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      await hw.HwAds.init();
      final ad = hw.BannerAd(
        adSlotId: kHuaweiBannerSlotId,
        size: hw.BannerAdSize.s320x50,
        adParam: hw.AdParam(),
      );
      _ad = ad;
      await ad.loadAd();
      await ad.show(gravity: hw.Gravity.bottom, offset: 0);
    } on Object {
      // No HMS Core / no fill / test env — never surface an error.
      await destroy();
    }
  }

  Future<void> destroy() async {
    try {
      await _ad?.destroy();
    } on Object {
      // Best-effort.
    }
    _ad = null;
  }
}
