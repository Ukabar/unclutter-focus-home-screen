import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_controller.dart';

class RemoteBannerAd extends StatefulWidget {
  const RemoteBannerAd({required this.controller, super.key});

  final AdsController controller;

  @override
  State<RemoteBannerAd> createState() => _RemoteBannerAdState();
}

class _RemoteBannerAdState extends State<RemoteBannerAd> {
  BannerAd? _bannerAd;
  bool _loaded = false;
  String? _loadedUnitId;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncAd);
    _syncAd();
  }

  @override
  void didUpdateWidget(RemoteBannerAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncAd);
      widget.controller.addListener(_syncAd);
      _disposeAd();
      _syncAd();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncAd);
    _disposeAd();
    super.dispose();
  }

  void _syncAd() {
    if (!mounted) {
      return;
    }
    final String? unitId = widget.controller.bannerAdUnitId();
    if (!widget.controller.canShowBanner || unitId == null) {
      setState(_disposeAd);
      return;
    }
    if (_bannerAd != null && _loadedUnitId == unitId) {
      return;
    }
    _disposeAd();
    final BannerAd ad = BannerAd(
      adUnitId: unitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _loaded = true;
            _loadedUnitId = unitId;
          });
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          if (mounted) {
            setState(() {
              _bannerAd = null;
              _loaded = false;
              _loadedUnitId = null;
            });
          }
        },
      ),
    );
    setState(() {
      _bannerAd = ad;
      _loaded = false;
      _loadedUnitId = unitId;
    });
    ad.load();
  }

  void _disposeAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _loaded = false;
    _loadedUnitId = null;
  }

  @override
  Widget build(BuildContext context) {
    final BannerAd? ad = _bannerAd;
    if (!_loaded || ad == null) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.center,
        child: SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}
