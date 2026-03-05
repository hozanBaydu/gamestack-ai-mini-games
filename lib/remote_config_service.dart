import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigService {

  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  Future<void> initialize() async {
    try {

      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(hours: 0),
      ));

      await _remoteConfig.setDefaults({

        'reklam_dakika_siniri': 240,
        'min_version': '1.0.0',
        'reklamlar_aktif_mi': true,
      });

      await _remoteConfig.fetchAndActivate();

      print("Remote Config: Güncel ayarlar çekildi ✅");
    } catch (e) {
      print("Remote Config Hatası: $e");
    }
  }

  int get reklamDakikaSiniri => _remoteConfig.getInt('reklam_dakika_siniri');

  String get minVersion => _remoteConfig.getString('min_version');

  bool get reklamlarAktifMi => _remoteConfig.getBool('reklamlar_aktif_mi');
}
