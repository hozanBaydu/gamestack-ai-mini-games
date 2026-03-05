import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomRateManager {

  static final CustomRateManager _instance = CustomRateManager._internal();
  static CustomRateManager get instance => _instance;
  CustomRateManager._internal();

  static const String _kSwipeCountKey = 'swipe_count_for_rate';
  static const String _kRateAskedKey = 'rate_asked_v1';
  static const int _kTargetSwipes = 7;

  final String _marketUrl = 'market://details?id=com.hozan.gamestack';
  final String _webUrl = 'https://play.google.com/store/apps/details?id=com.hozan.gamestack';

  int _currentSwipes = 0;
  bool _asked = false;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentSwipes = prefs.getInt(_kSwipeCountKey) ?? 0;
    _asked = prefs.getBool(_kRateAskedKey) ?? false;
  }

  Future<void> incrementSwipe(BuildContext context) async {

    if (_asked) return;

    _currentSwipes++;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSwipeCountKey, _currentSwipes);

    if (_currentSwipes == _kTargetSwipes) {

      _asked = true;
      await prefs.setBool(_kRateAskedKey, true);

      if (context.mounted) {
        _showRateDialog(context);
      }
    }
  }

  void _showRateDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                const Icon(Icons.rocket_launch_rounded, size: 50, color: Colors.blueAccent),
                const SizedBox(height: 16),

                const Text(
                  "Quick Break? 🚀",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                const Text(
                  "Looks like you're having fun! Want to make us happy?",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                Row(
                  children: [

                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          "Needs improvement 🧐",
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _launchStore();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          "Love it! 😍",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _launchStore() async {
    try {
      final Uri marketUri = Uri.parse(_marketUrl);
      final Uri webUri = Uri.parse(_webUrl);

      if (await canLaunchUrl(marketUri)) {
        await launchUrl(marketUri, mode: LaunchMode.externalApplication);
      } else {

        if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      debugPrint("Store launch error: $e");
    }
  }
}

