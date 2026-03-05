import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'remote_config_service.dart';

class ReklamYoneticisi {
  static final ReklamYoneticisi _instance = ReklamYoneticisi._internal();
  factory ReklamYoneticisi() => _instance;
  ReklamYoneticisi._internal();

  InterstitialAd? _gecisReklami;
  bool _reklamYukleniyor = false;

  DateTime _lastAdShowTime = DateTime.now();
  final String _testUnitId = 'ca-app-pub-3940256099942544/1033173712';

  // Security Update: Getting the real Admob ID from an environment variable
  // Build with: flutter build apk --dart-define=ADMOB_UNIT_ID=ca-app-pub-...
  final String _gercekUnitId = const String.fromEnvironment(
    'ADMOB_UNIT_ID', 
    defaultValue: 'YOUR_ADMOB_UNIT_ID_HERE'
  );

  String get _currentAdUnitId {
    if (kDebugMode) {
      return _testUnitId;
    } else {
      return _gercekUnitId;
    }
  }

  void reklamiYukle() {

    if (_gecisReklami != null || _reklamYukleniyor) return;
    if (RemoteConfigService().reklamlarAktifMi == false) return;

    _reklamYukleniyor = true;

    InterstitialAd.load(
      adUnitId: _currentAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          print('Reklam Yüklendi! 🟢');
          _gecisReklami = ad;
          _reklamYukleniyor = false;
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('Reklam Yüklenemedi: $error 🔴');
          _gecisReklami = null;
          _reklamYukleniyor = false;
        },
      ),
    );
  }

  bool shouldShowAd() {

    if (RemoteConfigService().reklamlarAktifMi == false) return false;

    final now = DateTime.now();
    final secondsSinceLastAd = now.difference(_lastAdShowTime).inSeconds;

    if (secondsSinceLastAd < 60) return false;

    int multiplier = 1;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.metadata.creationTime != null) {
      final hoursSinceCreation = now.difference(user.metadata.creationTime!).inHours;
      if (hoursSinceCreation < 24) {
        multiplier = 2;
      }
    }

    final thresholdSeconds = RemoteConfigService().reklamDakikaSiniri * multiplier;

    if (secondsSinceLastAd >= thresholdSeconds) {
      return true;
    }

    return false;
  }

  void reklamiGoster({required Function onClosed}) {
    if (_gecisReklami == null) {
      print('Reklam hazır değil, direkt oyuna geçiliyor.');
      reklamiYukle();
      onClosed();
      return;
    }

    _gecisReklami!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        print('Reklam kapatıldı, oyun devam ediyor. ▶️');
        _lastAdShowTime = DateTime.now();
        ad.dispose();
        _gecisReklami = null;
        reklamiYukle();
        onClosed();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        print('Reklam gösterilemedi hatası: $error');
        ad.dispose();
        _gecisReklami = null;
        onClosed();
      },
    );

    _gecisReklami!.show();
    _lastAdShowTime = DateTime.now();
  }
}
