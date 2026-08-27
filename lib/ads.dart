import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Development IDs only. Replace these with store-configured IDs at release time.
class MendologAdConfig {
  static const androidBannerUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const iosBannerUnitId = 'ca-app-pub-3940256099942544/2934735716';

  static String get bannerUnitId {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return iosBannerUnitId;
    }
    return androidBannerUnitId;
  }
}

class MonetizationBanner extends StatefulWidget {
  const MonetizationBanner({super.key});

  @override
  State<MonetizationBanner> createState() => _MonetizationBannerState();
}

class _MonetizationBannerState extends State<MonetizationBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    final ad = BannerAd(
      adUnitId: MendologAdConfig.bannerUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _ad = ad as BannerAd;
            _loaded = true;
          });
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) setState(() => _loaded = false);
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('monetization-banner'),
      width: AdSize.banner.width.toDouble(),
      height: AdSize.banner.height.toDouble(),
      child: _loaded && _ad != null ? AdWidget(ad: _ad!) : null,
    );
  }
}
