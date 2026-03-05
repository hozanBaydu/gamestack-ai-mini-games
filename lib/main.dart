import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:share_plus/share_plus.dart';
import 'remote_config_service.dart';
import 'custom_rate_manager.dart';
import 'reklam_yoneticisi.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'auth_pages.dart';
import 'friend_pages.dart';
import 'my_scores_screen.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'game_error_widget.dart';
import 'utils/music_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp();
  RemoteConfigService().initialize();
  MobileAds.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Game Feed',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.blueAccent,
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueAccent,
          secondary: Colors.purpleAccent,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    _checkUserStatus();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkUserStatus() async {

    await Future.delayed(const Duration(seconds: 3));

    User? user = FirebaseAuth.instance.currentUser;

    if (mounted) {
      if (user != null) {

        Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => const MainScaffold()));
      } else {

        try {
          UserCredential userCredential = await FirebaseAuth.instance.signInAnonymously();
          if (userCredential.user != null) {

            final int randomSuffix = DateTime.now().millisecondsSinceEpoch % 10000;
            final String guestNickname = "Guest$randomSuffix";

            final userDoc = await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).get();

            if (!userDoc.exists) {
               await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
                'uid': userCredential.user!.uid,
                'nickname': guestNickname,
                'is_guest': true,
                'created_at': FieldValue.serverTimestamp(),
                'score': 0,
                'interests': [],
              });
            }

            Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => const MainScaffold()));
          }
        } catch (e) {

          debugPrint("Auto guest login failed: $e");
           Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => const AuthSelectionScreen()));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F2027),
              Color(0xFF203A43),
              Color(0xFF2C5364),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Opacity(
                      opacity: _opacityAnimation.value,
                      child: Container(
                        height: 160,
                        width: 160,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          color: Colors.black.withOpacity(0.3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueAccent.withOpacity(0.4),
                              blurRadius: 40,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),
              const Text(
                "Welcome to GameStack",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 30),

              const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const FeedScreen(),
    const ProfileScreen(),
  ];

  Future<void> _checkFirstProfileVisit() async {
    final prefs = await SharedPreferences.getInstance();
    bool seen = prefs.getBool('tutorial_first_profile_seen') ?? false;

    if (!seen) {
      prefs.setBool('tutorial_first_profile_seen', true);

      if (mounted) {
        showDialog(
          context: context,
          barrierColor: Colors.transparent,
          builder: (context) => Stack(
            children: [
              Positioned(
                top: 60,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Icon(Icons.arrow_upward_rounded, color: Colors.amber, size: 40),
                    const SizedBox(height: 5),
                     Container(
                      padding: const EdgeInsets.all(10),
                      width: 200,
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.8),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(15),
                          topRight: Radius.circular(0),
                          bottomLeft: Radius.circular(15),
                          bottomRight: Radius.circular(15),
                        ),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Text(
                        "Tap here to add friends and compete!",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),

              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  behavior: HitTestBehavior.translucent,
                  child: Container(color: Colors.transparent),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),

      extendBody: false,
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          top: 12,
          left: 20,
          right: 20,
          bottom: 12 + MediaQuery.of(context).viewPadding.bottom,
        ),

        decoration: BoxDecoration(
          color: const Color(0xFF101010),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05), width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.gamepad_rounded, "Feed", 0),
            _buildNavItem(Icons.person_rounded, "Profile", 1),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        if (index == 1) {
          final reklamYoneticisi = ReklamYoneticisi();
          if (reklamYoneticisi.shouldShowAd()) {
            reklamYoneticisi.reklamiGoster(onClosed: () {
              setState(() => _currentIndex = index);
              _checkFirstProfileVisit();
            });
          } else {
            setState(() => _currentIndex = index);
             _checkFirstProfileVisit();
          }
        } else {
           setState(() => _currentIndex = index);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 20 : 16, vertical: 10),
        decoration: isSelected
            ? BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blueAccent.shade700, Colors.blueAccent.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.5),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              )
            : const BoxDecoration(
                color: Colors.transparent,
              ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 26,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with WidgetsBindingObserver {
  bool _showTutorial = false;
  int _tutorialStep = 0;

  List<DocumentSnapshot> _stableFeed = [];

  late PageController _pageController;

  late Future<DocumentSnapshot> _userDislikesFuture;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    MusicManager.instance.stopMusic();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pageController = PageController();

    _userDislikesFuture = FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .get();

    _checkTutorialStatus();

    ReklamYoneticisi().reklamiYukle();

    CustomRateManager.instance.init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        MusicManager.instance.pauseMusic();
        break;
      case AppLifecycleState.resumed:
        MusicManager.instance.resumeMusic();
        break;
    }
  }

  Future<void> _checkTutorialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    bool seen = prefs.getBool('tutorial_seen') ?? false;
    if (!seen) {
    setState(() {
      _showTutorial = true;
      _tutorialStep = 0;
    });
  }
}

Future<void> _closeTutorial() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('tutorial_seen', true);
  setState(() { _showTutorial = false; });
}

void _startNudgeLoop() async {
  if (_tutorialStep != 1 || !_showTutorial) return;

  await Future.delayed(const Duration(seconds: 1));
  if (!mounted || _tutorialStep != 1 || !_showTutorial) return;

  if (_pageController.hasClients) {

      await _pageController.animateTo(
        160.0,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOut,
      );

      if (!mounted || _tutorialStep != 1 || !_showTutorial) {

        if (_pageController.hasClients && _pageController.offset > 0) {
           _pageController.jumpTo(0);
        }
        return;
      }

      await _pageController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOut,
      );
  }

  _startNudgeLoop();
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(

        backgroundColor: const Color(0xFF101010),
        elevation: 0,
        toolbarHeight: 70,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF101010),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05), width: 1)),
             boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, 2),
              )
            ]
          ),
        ),
        centerTitle: false,
        title: Row(
          children: [
            Container(
              height: 42, width: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color.fromARGB(255, 17, 16, 16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.5),
                    blurRadius: 8, spreadRadius: 0,
                  )
                ],
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "GAMESTACK",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.5,
                    fontFamily: 'Roboto',
                  ),
                ),
                const Text(
                  "SWIPE & PLAY",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.blueAccent,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: MusicManager.instance.isMutedNotifier,
            builder: (context, isMuted, child) {
              return IconButton(
                 icon: Icon(
                  isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                ),
                onPressed: () {
                  MusicManager.instance.toggleMute();
                },
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: Stack(
        children: [

          FutureBuilder<DocumentSnapshot>(
            future: _userDislikesFuture,
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              List<dynamic> dislikedGames = [];
                String nickname = '';

              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                dislikedGames = userData['disliked_games'] ?? [];
                nickname = userData['nickname'] ?? '';
              }

              Query gamesQuery = FirebaseFirestore.instance.collection('oyunlar');

              const adminList = ['hozanbaydu', 'hozanbaydu2'];

              if (!adminList.contains(nickname)) {

                gamesQuery = gamesQuery.where('GameIsActive', isEqualTo: true);
              }

              return StreamBuilder(
                stream: gamesQuery.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var tumBelgeler = snapshot.data?.docs ?? [];

                  var belgeler = tumBelgeler.where((doc) {
                    return !dislikedGames.contains(doc.id);
                  }).toList();

                  if (belgeler.isEmpty) {

                    if (tumBelgeler.isNotEmpty) {
                       return const Center(child: Text("All games hidden! Clear dislikes in profile.", style: TextStyle(color: Colors.white)));
                    }
                    return const Center(child: Text("Oyun bulunamadı.", style: TextStyle(color: Colors.white)));
                  }

                  if (_stableFeed.isEmpty && belgeler.isNotEmpty) {
                     _stableFeed = getFinalFeed(belgeler);

                     if (_stableFeed.isNotEmpty) {

                       Future.delayed(Duration.zero, () {
                         var data = _stableFeed[0].data() as Map<String, dynamic>;
                         int? musicId = data['music_id'];
                         MusicManager.instance.playMusic(musicId);
                       });
                     }
                  }

                  if (_stableFeed.isEmpty) {
                      return const Center(child: Text("Oyun bulunamadı.", style: TextStyle(color: Colors.white)));
                  }

                  return PageView.builder(
                    controller: _pageController,
                    scrollDirection: Axis.vertical,
                    itemCount: _stableFeed.length,

                    onPageChanged: (int index) {

                       if (_showTutorial && _tutorialStep == 1 && index > 0) {
                         setState(() {
                           _tutorialStep = 2;
                         });

                       }

                       CustomRateManager.instance.incrementSwipe(context);

                       if (index < _stableFeed.length) {
                         var data = _stableFeed[index].data() as Map<String, dynamic>;

                         int? musicId = data['music_id'];
                         MusicManager.instance.playMusic(musicId);
                       }

                       final reklamYoneticisi = ReklamYoneticisi();

                       if (reklamYoneticisi.shouldShowAd()) {
                         print("🎯 REKLAM TETİKLENDİ (Time-Based)!");
                         reklamYoneticisi.reklamiGoster(onClosed: () {

                           setState(() {});
                         });
                       }
                    },

                    itemBuilder: (context, index) {
                      var data = _stableFeed[index].data() as Map<String, dynamic>;
                      String oyunLinki = data['url'];
                      String oyunId = _stableFeed[index].id;
                      String oyunAdi = data['name'] ?? 'Game';
                      String gameType = data['type'] ?? 'type1';

                      return OyunPenceresi(url: oyunLinki, docId: oyunId, gameName: oyunAdi, gameType: gameType);
                    },
                  );
                },
              );
            }
          ),

          if (_showTutorial)
            TutorialOverlay(
              currentStep: _tutorialStep,
              onNextStep: () {
                setState(() {
                  _tutorialStep++;
                  if (_tutorialStep == 1) {
                    _startNudgeLoop();
                  }
                });
              },
              onClose: _closeTutorial,
            ),
        ],
      ),
    );
  }

  List<DocumentSnapshot> getFinalFeed(List<DocumentSnapshot> rawGames) {

    final remoteConfig = FirebaseRemoteConfig.instance;

    bool isActive = remoteConfig.getBool('feed_algo_strategy');

    debugPrint("--- FEED ALGO DEBUG ---");
    debugPrint("RemoteConfig isActive: $isActive");
    debugPrint("Total Games: ${rawGames.length}");

    if (!isActive || rawGames.length < 5) {
      debugPrint("FALLBACK MODE: Shuffle only (Not enough games or algo disabled)");
      List<DocumentSnapshot> simpleList = List.from(rawGames);
      simpleList.shuffle();
      return simpleList;
    }

    debugPrint("SMART MODE: Calculating Scores...");

    List<DocumentSnapshot> shuffledGames = List.from(rawGames);
    shuffledGames.shuffle();

    double calculateScore(DocumentSnapshot doc) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};

      int likesCount = (data['likes_count'] ?? 0).toInt();
      int playCount = (data['total_play_count'] ?? 0).toInt();
      double avgTime = (data['average_play_time'] ?? 0).toDouble();

      int safePlayCount = playCount > 0 ? playCount : 1;

      double score = ((100 * likesCount) / safePlayCount) + avgTime;

      return score;
    }

    shuffledGames.sort((a, b) {
      double scoreA = calculateScore(a);
      double scoreB = calculateScore(b);
      return scoreB.compareTo(scoreA);
    });

    debugPrint("--- TOP SCORES ---");
    for(var i=0; i< (shuffledGames.length > 5 ? 5 : shuffledGames.length); i++) {
      var d = shuffledGames[i];
      debugPrint("${i+1}. ${d.id} - Score: ${calculateScore(d)}");
    }

    List<DocumentSnapshot> finalFeed = [];
    Set<String> addedIds = {};

    void addGame(DocumentSnapshot doc) {
      if (!addedIds.contains(doc.id)) {
        finalFeed.add(doc);
        addedIds.add(doc.id);
      }
    }

    for (int i = 0; i < 2; i++) {
        if (i < shuffledGames.length) addGame(shuffledGames[i]);
    }

    List<DocumentSnapshot> remainingPool = shuffledGames.where((doc) => !addedIds.contains(doc.id)).toList();
    remainingPool.shuffle();

    for (int i = 0; i < 2; i++) {
      if (i < remainingPool.length) addGame(remainingPool[i]);
    }

    List<DocumentSnapshot> lastBatch = shuffledGames.where((doc) => !addedIds.contains(doc.id)).toList();

     lastBatch.sort((a, b) => calculateScore(b).compareTo(calculateScore(a)));

    for (var doc in lastBatch) {
      addGame(doc);
    }

    debugPrint("--- FINAL FEED ORDER ---");
    debugPrint(finalFeed.map((e) => e.id).join(' -> '));

    return finalFeed;
  }
}

class TutorialOverlay extends StatefulWidget {
  final int currentStep;
  final VoidCallback onNextStep;
  final VoidCallback onClose;

  const TutorialOverlay({
    super.key,
    required this.currentStep,
    required this.onNextStep,
    required this.onClose
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1000),
      )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [

        if (widget.currentStep != 1)

          Container(color: Colors.black.withOpacity(0.85))
        else

          Row(
            children: [

              Expanded(
                child: AbsorbPointer(
                  absorbing: true,
                  child: Container(color: Colors.black.withOpacity(0.85)),
                ),
              ),

              IgnorePointer(
                ignoring: true,
                child: Container(
                  width: 92,
                  color: Colors.black.withOpacity(0.85),
                ),
              ),
            ],
          ),

        if (widget.currentStep == 0)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.touch_app, size: 80, color: Colors.blueAccent),
                  const SizedBox(height: 20),
                  const Text("The center is for\nGAMING.",
                      style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, height: 1.2)),
                  const SizedBox(height: 15),
                  const Text("Enjoy full touch controls without accidental scrolling!",
                      style: TextStyle(color: Colors.white70, fontSize: 18)),
                  const SizedBox(height: 40),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: widget.onNextStep,
                      icon: const Icon(Icons.arrow_forward, color: Colors.white),
                      label: const Text("NEXT", style: TextStyle(color: Colors.white, fontSize: 18)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        if (widget.currentStep == 1)
          IgnorePointer(
             ignoring: true,
             child: Stack(
              children: [

                Positioned(
                  right: 2,
                  top: 0,
                  bottom: 0,
                  child: AnimatedBuilder(
                     animation: _controller,
                     builder: (context, child) {
                       return Opacity(
                         opacity: 0.5 + (_controller.value * 0.5),
                         child: Container(
                          width: 80,
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Center(
                            child: Icon(Icons.swap_vert, color: Colors.white, size: 40),
                          ),
                        ),
                       );
                     }
                  ),
                ),

                Positioned(
                  right: 80,
                  top: MediaQuery.of(context).size.height * 0.35,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [

                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, -20 + (_controller.value * 40)),
                            child: const Icon(Icons.pan_tool_alt, color: Colors.white, size: 60),
                          );
                        },
                      ),
                      const SizedBox(height: 10),

                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          return Opacity(
                            opacity: 0.5 + (_controller.value * 0.5),
                            child: const Text("Swipe here\nto scroll 👉",
                                textAlign: TextAlign.right,
                                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        if (widget.currentStep == 2)
            Stack(
              children: [
                Positioned(
                  right: 70,
                  bottom: 145,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        width: 200,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.9),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(0),
                          ),
                          border: Border.all(color: Colors.amber, width: 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text("World Ranking 🏆",
                                style: TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
                            SizedBox(height: 4),
                            Text("Tap here to see the Global Leaderboard!",
                                style: TextStyle(color: Colors.white, fontSize: 13)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(_controller.value * 10, 0),
                            child: const Icon(Icons.arrow_forward_rounded, color: Colors.amber, size: 50),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 50.0),
                    child: ElevatedButton(
                      onPressed: widget.onClose,
                       style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 153, 233, 91),
                        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text("GOT IT, LET'S PLAY!",
                          style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
        ],
      );
  }
}

class OyunPenceresi extends StatefulWidget {
  final String url;
  final String docId;
  final String gameName;
  final String gameType;

  const OyunPenceresi({super.key, required this.url, required this.docId, required this.gameName, required this.gameType});

  @override
  State<OyunPenceresi> createState() => _OyunPenceresiState();
}

class _OyunPenceresiState extends State<OyunPenceresi> with WidgetsBindingObserver {
  late final WebViewController controller;
  bool _showBigHeart = false;
  bool _isError = false;
  DateTime? _sessionStartTime;
  Timer? _adTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionStartTime = DateTime.now();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (WebResourceError error) {
            debugPrint("WebView Error: ${error.description}");

            if (mounted) {
              setState(() => _isError = true);
            }
          },
          onNavigationRequest: (request) => NavigationDecision.navigate,
        ),
      )
      ..addJavaScriptChannel(
        'GameStack',
        onMessageReceived: (JavaScriptMessage message) {
          _handleGameMessage(message.message);
        },
      );

    _checkConnectivityAndLoad();

    if (widget.gameType == 'type2') {

      _adTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        final reklamYoneticisi = ReklamYoneticisi();
        if (reklamYoneticisi.shouldShowAd()) {
          print("⏰ TYPE 2 - Timer Tetiklendi ve Şartlar Sağlandı!");

          reklamYoneticisi.reklamiGoster(onClosed: () {

          });
        }
      });
    }
  }

  Future<void> _checkConnectivityAndLoad() async {

    final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());

    bool isOffline = connectivityResult.contains(ConnectivityResult.none);

    bool hasConnection = connectivityResult.any((element) =>
      element == ConnectivityResult.mobile ||
      element == ConnectivityResult.wifi ||
      element == ConnectivityResult.ethernet ||
      element == ConnectivityResult.vpn
    );

    if (isOffline || !hasConnection) {
      if (mounted) setState(() => _isError = true);
      return;
    }

    if (mounted) setState(() => _isError = false);
    controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _endSession();
    _adTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {

      _endSession();
    } else if (state == AppLifecycleState.resumed) {

      _sessionStartTime = DateTime.now();
    }
  }

  void _endSession() {
    if (_sessionStartTime != null) {
      final int sessionDuration = DateTime.now().difference(_sessionStartTime!).inSeconds;

      if (sessionDuration > 0) {
        updateGameStats(widget.docId, sessionDuration.toDouble());
      }

      _sessionStartTime = null;
    }
  }

  Future<void> _handleGameMessage(String message) async {
    if (message.startsWith("score:")) {
      try {
        int newScore = int.parse(message.split(":")[1]);
        await _saveScoreToFirebase(newScore);

        if (widget.gameType == 'type1') {
          final reklamYoneticisi = ReklamYoneticisi();

          if (reklamYoneticisi.shouldShowAd()) {
             print("💀 TYPE 1 - Game Over ve Şartlar Sağlandı!");

             Future.delayed(const Duration(milliseconds: 800), () {
               if (mounted) {
                 reklamYoneticisi.reklamiGoster(onClosed: () {

                 });
               }
             });
          }
        }

      } catch (e) {
        debugPrint("Skor okuma hatası: $e");
      }
    }
  }

  Future<void> _saveScoreToFirebase(int newScore) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final scoreRef = userRef.collection('game_scores').doc(widget.docId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot scoreDoc = await transaction.get(scoreRef);
        DocumentSnapshot userDoc = await transaction.get(userRef);

        int currentBest = 0;
        if (scoreDoc.exists) {
          currentBest = (scoreDoc.data() as Map<String, dynamic>)['score'] ?? 0;
        }

        if (newScore > currentBest) {

          transaction.set(scoreRef, {
            'score': newScore,
            'gameName': widget.gameName,
            'type': widget.gameType,
            'timestamp': FieldValue.serverTimestamp(),
          });

          if (widget.gameType != 'type2') {
            int scoreDifference = newScore - currentBest;
            int currentTotalScore = (userDoc.data() as Map<String, dynamic>)['score'] ?? 0;

            transaction.update(userRef, {
              'score': currentTotalScore + scoreDifference,
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF1E1E1E),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  padding: EdgeInsets.zero,
                  duration: const Duration(seconds: 5),
                  content: Stack(
                    children: [

                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 24),
                          onPressed: () {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          },

                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                      ),

                      Padding(

                        padding: const EdgeInsets.fromLTRB(16, 30, 16, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [

                            Row(
                              children: [
                                const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "New Record: $newScore! 🏆",
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                      ),
                                      Text(
                                        "+${scoreDifference} to Total Score",
                                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {

                                  final String shareText = "I scored $newScore on GameStack! 🔥 Beat me if you can! 🚀\n\nDownload and Play: https://play.google.com/store/apps/details?id=com.hozan.gamestack";
                                  Share.share(shareText, subject: "I Challenge You!");
                                },
                                icon: const Icon(Icons.share_rounded, size: 18, color: Colors.white),
                                label: const Text("Challenge Friend", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          }

          if (widget.gameType != 'type2') {
            DocumentReference leaderboardRef = FirebaseFirestore.instance
                .collection('games')
                .doc(widget.docId)
                .collection('leaderboard')
                .doc(user.uid);

            transaction.set(leaderboardRef, {
              'score': newScore,
              'userId': user.uid,
              'nickname': (userDoc.data() as Map<String, dynamic>)['nickname'] ?? 'User',
              'timestamp': FieldValue.serverTimestamp(),
            });
          }
        }
      });
    } catch (e) {
      debugPrint("Skor kaydetme hatası: $e");
    }
  }

  void triggerHeartAnimation() {
    setState(() => _showBigHeart = true);
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _showBigHeart = false);
    });
  }

  Future<void> updateGameStats(String gameId, double sessionSeconds) async {

    DocumentReference gameRef = FirebaseFirestore.instance.collection('oyunlar').doc(gameId);

    try {
      final double finalAverageTime = await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(gameRef);

        if (!snapshot.exists) {
          throw Exception("Game document not found!");
        }

        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>? ?? {};

        double currentTotalTime = (data['total_play_time'] ?? 0).toDouble();
        int currentPlayCount = (data['total_play_count'] ?? 0).toInt();

        double newTotalTime = currentTotalTime + sessionSeconds;
        int newPlayCount = currentPlayCount + 1;

        double rawAverage = newPlayCount > 0 ? (newTotalTime / newPlayCount) : 0.0;

        double newAverageTime = double.parse(rawAverage.toStringAsFixed(6));

        transaction.update(gameRef, {
          'total_play_time': newTotalTime,
          'total_play_count': newPlayCount,
          'average_play_time': newAverageTime,
        });

        return newAverageTime;
      });

      debugPrint("Game Stats Updated: Id: $gameId, Avg: $finalAverageTime s");
    } catch (e) {
      debugPrint("Stats update error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [

        _isError
            ? GameErrorWidget(onRetry: () {
                _checkConnectivityAndLoad();
              })
            : WebViewWidget(

                controller: controller,
                gestureRecognizers: {
                  Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                },
              ),

        Positioned(
          right: 10,
          bottom: 150,
          child: GameActionsBar(
            gameId: widget.docId,
            gameType: widget.gameType,
            onLike: triggerHeartAnimation,
          ),
        ),

        if (_showBigHeart)
          Center(
            child: TweenAnimationBuilder(
              duration: const Duration(milliseconds: 800),
              tween: Tween<double>(begin: 0.0, end: 1.0),
              curve: Curves.elasticOut,
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: value * 4.0,
                  child: const Icon(Icons.favorite, color: Colors.red, size: 50),
                );
              },
            ),
          ),

        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: 30,
          child: Container(color: Colors.transparent),
        ),

        Positioned(
          left: 20,
          bottom: 20,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.gameName,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),

      ],
    );
  }
}

class GameActionsBar extends StatefulWidget {
  final String gameId;
  final String gameType;
  final VoidCallback onLike;

  const GameActionsBar({super.key, required this.gameId, required this.gameType, required this.onLike});

  @override
  State<GameActionsBar> createState() => _GameActionsBarState();
}

class _GameActionsBarState extends State<GameActionsBar> {
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  CollectionReference get gameLikesRef => FirebaseFirestore.instance
      .collection('oyunlar')
      .doc(widget.gameId)
      .collection('likes');

  CollectionReference get gameDislikesRef => FirebaseFirestore.instance
      .collection('oyunlar')
      .doc(widget.gameId)
      .collection('dislikes');

  CollectionReference get gameSavesRef => FirebaseFirestore.instance
      .collection('oyunlar')
      .doc(widget.gameId)
      .collection('saves');

  DocumentReference get userRef => FirebaseFirestore.instance
      .collection('users')
      .doc(userId);

  Future<void> _checkFirstLikeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    bool seen = prefs.getBool('tutorial_first_like_seen') ?? false;

    if (!seen) {
      prefs.setBool('tutorial_first_like_seen', true);

      if (mounted) {
        showDialog(
          context: context,
          barrierColor: Colors.transparent,
          builder: (context) => Stack(
            children: [

              Positioned(
                bottom: 80,
                right: 50,
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                       Container(
                        padding: const EdgeInsets.all(12),
                        width: 200,
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.9),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(0),
                          ),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Text(
                          "Liked it?\nTap here to find and play your liked games!",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Icon(Icons.arrow_downward_rounded, color: Colors.blueAccent, size: 50),
                    ],
                  ),
                ),
              ),

              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  behavior: HitTestBehavior.translucent,
                  child: Container(color: Colors.transparent),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> handleLike(bool isLiked, bool isDisliked) async {

    WriteBatch batch = FirebaseFirestore.instance.batch();

    if (isLiked) {

      batch.delete(gameLikesRef.doc(userId));
      batch.update(userRef, {
        'liked_games': FieldValue.arrayRemove([widget.gameId])
      });
    } else {

      batch.set(gameLikesRef.doc(userId), {'timestamp': FieldValue.serverTimestamp()});

      batch.set(userRef, {
        'liked_games': FieldValue.arrayUnion([widget.gameId]),

        'disliked_games': FieldValue.arrayRemove([widget.gameId])
      }, SetOptions(merge: true));

      widget.onLike();

      _checkFirstLikeTutorial();

      if (isDisliked) {
        batch.delete(gameDislikesRef.doc(userId));
      }
    }

    await batch.commit();
  }

  Future<void> handleDislike(bool isLiked, bool isDisliked) async {
    WriteBatch batch = FirebaseFirestore.instance.batch();

    if (isDisliked) {

      batch.delete(gameDislikesRef.doc(userId));
      batch.update(userRef, {
        'disliked_games': FieldValue.arrayRemove([widget.gameId])
      });
    } else {

      batch.set(gameDislikesRef.doc(userId), {'timestamp': FieldValue.serverTimestamp()});

      batch.set(userRef, {
        'disliked_games': FieldValue.arrayUnion([widget.gameId]),
        'liked_games': FieldValue.arrayRemove([widget.gameId])
      }, SetOptions(merge: true));

      if (isLiked) {
        batch.delete(gameLikesRef.doc(userId));
      }
    }

    await batch.commit();

    if (!isDisliked && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.remove_circle_outline, color: Colors.white),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "We won't suggest this game to you anymore.",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.grey[900],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> handleSave(bool isSaved) async {
    WriteBatch batch = FirebaseFirestore.instance.batch();

    if (isSaved) {

      batch.delete(gameSavesRef.doc(userId));
      batch.update(userRef, {
        'saved_games': FieldValue.arrayRemove([widget.gameId])
      });
    } else {

      batch.set(gameSavesRef.doc(userId), {'timestamp': FieldValue.serverTimestamp()});
      batch.set(userRef, {
        'saved_games': FieldValue.arrayUnion([widget.gameId])
      }, SetOptions(merge: true));

      _checkFirstSaveTutorial();
    }

    await batch.commit();

    if (!isSaved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Game Saved!"), duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _checkFirstSaveTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    bool seen = prefs.getBool('tutorial_first_save_seen') ?? false;

    if (!seen) {
      prefs.setBool('tutorial_first_save_seen', true);

      if (mounted) {
        showDialog(
          context: context,
          barrierColor: Colors.transparent,
          builder: (context) => Stack(
            children: [

              Positioned(
                bottom: 80,
                right: 50,
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                       Container(
                        padding: const EdgeInsets.all(12),
                        width: 200,
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.9),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(0),
                          ),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Text(
                          "Saved!\nTap here to find and play your saved games!",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Icon(Icons.arrow_downward_rounded, color: Colors.amber, size: 50),
                    ],
                  ),
                ),
              ),

              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  behavior: HitTestBehavior.translucent,
                  child: Container(color: Colors.transparent),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  static final ValueNotifier<bool> isExpandedNotifier = ValueNotifier(true);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isExpandedNotifier,
      builder: (context, isExpanded, child) {
        return GestureDetector(
          onTap: () {

            if (!isExpanded) {
              isExpandedNotifier.value = true;
            }
          },
          behavior: HitTestBehavior.translucent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              color: isExpanded ? Colors.black.withOpacity(0.4) : Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            padding: EdgeInsets.symmetric(
              vertical: isExpanded ? 20 : 10,
              horizontal: isExpanded ? 8 : 4
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                GestureDetector(
                  onTap: () {
                    isExpandedNotifier.value = !isExpandedNotifier.value;
                  },
                  child: Container(
                    margin: EdgeInsets.only(bottom: isExpanded ? 15 : 0),
                    padding: const EdgeInsets.all(8),
                     decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                    ),
                    child: Icon(
                      isExpanded ? Icons.keyboard_arrow_right_rounded : Icons.keyboard_arrow_left_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),

              AnimatedCrossFade(
                firstChild: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    StreamBuilder(
                      stream: gameLikesRef.snapshots(),
                      builder: (context, likeSnapshot) {
                        bool isLiked = likeSnapshot.data?.docs.any((doc) => doc.id == userId) ?? false;
                        int likeCount = likeSnapshot.data?.docs.length ?? 0;

                        return StreamBuilder(
                          stream: gameDislikesRef.snapshots(),
                          builder: (context, dislikeSnapshot) {
                             bool isDisliked = dislikeSnapshot.data?.docs.any((doc) => doc.id == userId) ?? false;

                             return Column(
                               children: [
                                 _buildActionButton(
                                   icon: Icons.favorite,
                                   color: isLiked ? Colors.redAccent : Colors.white.withOpacity(0.5),
                                   label: "$likeCount",
                                   onTap: () => handleLike(isLiked, isDisliked),
                                 ),
                                 const SizedBox(height: 15),

                                 _buildActionButton(
                                   icon: isDisliked ? Icons.thumb_down : Icons.thumb_down_alt_outlined,
                                   color: isDisliked ? Colors.blueAccent : Colors.white.withOpacity(0.5),
                                   label: "",
                                   onTap: () => handleDislike(isLiked, isDisliked),
                                 ),
                               ],
                             );
                          }
                        );
                      },
                    ),
                    const SizedBox(height: 15),

                    StreamBuilder(
                      stream: gameSavesRef.snapshots(),
                      builder: (context, saveSnapshot) {
                        bool isSaved = saveSnapshot.data?.docs.any((doc) => doc.id == userId) ?? false;

                        return _buildActionButton(
                          icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
                          color: isSaved ? Colors.amber : Colors.white.withOpacity(0.5),
                          label: isSaved ? "Saved" : "",
                          onTap: () => handleSave(isSaved),
                        );
                      },
                    ),
                    const SizedBox(height: 15),

                    _buildActionButton(
                      icon: Icons.comment_rounded,
                      color: Colors.white.withOpacity(0.5),
                      label: "",
                      onTap: () {

                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => CommentSheet(gameId: widget.gameId),
                        );
                      },
                    ),
                    const SizedBox(height: 15),

                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .collection('game_scores')
                          .doc(widget.gameId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        int bestScore = 0;
                        if (snapshot.hasData && snapshot.data!.exists) {
                          var data = snapshot.data!.data() as Map<String, dynamic>;
                          bestScore = data['score'] ?? 0;
                        }

                        return GestureDetector(
                          onTap: widget.gameType == 'type2' ? null : () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => LeaderboardSheet(gameId: widget.gameId),
                            );
                          },
                          child: Column(
                            children: [
                               Container(
                                 padding: const EdgeInsets.all(8),
                                 decoration: BoxDecoration(
                                   shape: BoxShape.circle,
                                   border: Border.all(
                                     color: widget.gameType == 'type2' ? Colors.grey.withOpacity(0.5) : Colors.amber.withOpacity(0.5),
                                     width: 2
                                   ),
                                   color: Colors.black.withOpacity(0.2),
                                 ),
                                 child: Icon(Icons.emoji_events, color: widget.gameType == 'type2' ? Colors.grey : Colors.amber, size: 24),
                               ),
                               const SizedBox(height: 4),
                               if (widget.gameType != 'type2')
                                 Text(
                                   "$bestScore",
                                   style: const TextStyle(
                                     color: Colors.amberAccent,
                                     fontWeight: FontWeight.bold,
                                     fontSize: 12,
                                   ),
                                 )
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                secondChild: const SizedBox.shrink(),
                crossFadeState: isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                duration: const Duration(milliseconds: 300),
              ),

            ],
          ),
          ),
        );
      }
    );
  }

  Widget _buildActionButton({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: color, size: 32),
          ),
          if (label.isNotEmpty)
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12
              ),
            ),
        ],
      ),
    );
  }
}

class CommentSheet extends StatefulWidget {
  final String gameId;
  const CommentSheet({super.key, required this.gameId});

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  final TextEditingController _commentController = TextEditingController();
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  bool _isPosting = false;

  Future<void> _postComment() async {
    String text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPosting = true);

    try {

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();

      String nickname = "Anonymous";
      if (userDoc.exists) {
        nickname = userDoc['nickname'] ?? "Unknown";
      }

      WriteBatch batch = FirebaseFirestore.instance.batch();

      DocumentReference gameCommentRef = FirebaseFirestore.instance
          .collection('oyunlar')
          .doc(widget.gameId)
          .collection('comments')
          .doc();

      DocumentReference userCommentRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('comments')
          .doc(gameCommentRef.id);

      Map<String, dynamic> commentData = {
        'text': text,
        'userId': currentUserId,
        'nickname': nickname,
        'timestamp': FieldValue.serverTimestamp(),
        'gameId': widget.gameId,
      };

      batch.set(gameCommentRef, commentData);
      batch.set(userCommentRef, commentData);

      await batch.commit();

      _commentController.clear();

      if (mounted) FocusScope.of(context).unfocus();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text("Are you sure?", style: TextStyle(color: Colors.white)),
        content: const Text("Do you want to delete this comment?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      DocumentReference gameCommentRef = FirebaseFirestore.instance
          .collection('oyunlar')
          .doc(widget.gameId)
          .collection('comments')
          .doc(commentId);

      DocumentReference userCommentRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('comments')
          .doc(commentId);

      batch.delete(gameCommentRef);
      batch.delete(userCommentRef);

      await batch.commit();
    } catch (e) {
      debugPrint("Silme hatası: $e");
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "Just now";

    final DateTime now = DateTime.now();
    final DateTime date = timestamp.toDate();
    final Duration diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return "${diff.inMinutes} min";
    } else if (diff.inHours < 24) {
      return "${diff.inHours} h";
    } else if (diff.inDays < 7) {
      return "${diff.inDays} day${diff.inDays > 1 ? 's' : ''}";
    } else {
      int weeks = (diff.inDays / 7).floor();
      return "$weeks week${weeks > 1 ? 's' : ''}";
    }
  }

  @override
  Widget build(BuildContext context) {

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 50,
            spreadRadius: 5,
          )
        ],
      ),
      child: Column(
        children: [

          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Comments", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(

              stream: FirebaseFirestore.instance
                  .collection('games')
                  .doc(widget.gameId)
                  .collection('leaderboard')
                  .orderBy('score', descending: true)
                  .limit(3)
                  .snapshots(),
              builder: (context, leaderboardSnapshot) {

                Map<String, int> topScorers = {};
                if (leaderboardSnapshot.hasData) {
                  var leaders = leaderboardSnapshot.data!.docs;
                  for (int i = 0; i < leaders.length; i++) {
                    topScorers[leaders[i]['userId']] = i + 1;
                  }
                }

                return StreamBuilder<QuerySnapshot>(

                  stream: FirebaseFirestore.instance
                      .collection('oyunlar')
                      .doc(widget.gameId)
                      .collection('comments')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, commentSnapshot) {
                    if (commentSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    var docs = commentSnapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, size: 60, color: Colors.grey[800]),
                            const SizedBox(height: 15),
                            Text("No comments yet.", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                          ],
                        ),
                      );
                    }

                    List<DocumentSnapshot> sortedDocs = List.from(docs);

                    Map<String, int> commentRanks = {};
                    Set<String> processedRankedUsers = {};

                    for (var doc in sortedDocs) {
                      String uid = (doc.data() as Map<String, dynamic>)['userId'];
                      if (topScorers.containsKey(uid)) {
                        if (!processedRankedUsers.contains(uid)) {

                          commentRanks[doc.id] = topScorers[uid]!;
                          processedRankedUsers.add(uid);
                        } else {

                          commentRanks[doc.id] = 999;
                        }
                      } else {
                        commentRanks[doc.id] = 999;
                      }
                    }

                    sortedDocs.sort((a, b) {
                      int rankA = commentRanks[a.id] ?? 999;
                      int rankB = commentRanks[b.id] ?? 999;

                      if (rankA != rankB) {
                        return rankA.compareTo(rankB);
                      }

                      Timestamp timeA = (a.data() as Map<String, dynamic>)['timestamp'] ?? Timestamp.now();
                      Timestamp timeB = (b.data() as Map<String, dynamic>)['timestamp'] ?? Timestamp.now();
                      return timeB.compareTo(timeA);
                    });

                    return ListView.separated(
                      padding: const EdgeInsets.all(20),
                      separatorBuilder: (context, index) => const SizedBox(height: 15),
                      itemCount: sortedDocs.length,
                      itemBuilder: (context, index) {
                        var data = sortedDocs[index].data() as Map<String, dynamic>;
                        String commentId = sortedDocs[index].id;
                        String writerId = data['userId'];
                        bool isMyComment = writerId == currentUserId;

                        int rank = commentRanks[commentId] ?? 0;
                        if (rank > 3) rank = 0;

                        Color containerColor = Colors.transparent;
                        Color borderColor = Colors.transparent;
                        Widget? rankBadge;

                        if (rank == 1) {
                          containerColor = const Color(0xFFFFD700).withOpacity(0.15);
                          borderColor = const Color(0xFFFFD700);
                          rankBadge = _buildRankBadge("1", const Color(0xFFFFD700));
                        } else if (rank == 2) {
                          containerColor = const Color(0xFFC0C0C0).withOpacity(0.15);
                          borderColor = const Color(0xFFC0C0C0);
                          rankBadge = _buildRankBadge("2", const Color(0xFFC0C0C0));
                        } else if (rank == 3) {
                          containerColor = const Color(0xFFCD7F32).withOpacity(0.15);
                          borderColor = const Color(0xFFCD7F32);
                          rankBadge = _buildRankBadge("3", const Color(0xFFCD7F32));
                        }

                        return Container(
                          decoration: rank > 0 ? BoxDecoration(
                            color: containerColor,
                            border: Border.all(color: borderColor.withOpacity(0.5), width: 1),
                            borderRadius: BorderRadius.circular(15),
                          ) : null,
                          padding: rank > 0 ? const EdgeInsets.all(10) : EdgeInsets.zero,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.primaries[writerId.hashCode % Colors.primaries.length].withOpacity(0.8),
                                    child: Text(
                                      (data['nickname'] ?? "U")[0].toUpperCase(),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                                    ),
                                  ),
                                  if (rankBadge != null)
                                    Positioned(
                                      right: -5,
                                      bottom: -5,
                                      child: rankBadge,
                                    ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          data['nickname'] ?? "Unknown",
                                          style: TextStyle(
                                            color: rank > 0 ? borderColor : Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (rank > 0) ...[
                                          const SizedBox(width: 5),
                                          Icon(Icons.emoji_events, size: 14, color: borderColor),
                                        ],
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatTimestamp(data['timestamp']),
                                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                        ),
                                        if (isMyComment) ...[
                                          const Spacer(),
                                          GestureDetector(
                                            onTap: () => _deleteComment(commentId),
                                            child: const Icon(Icons.delete_outline, color: Colors.grey, size: 18),
                                          )
                                        ]
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      data['text'] ?? "",
                                      style: const TextStyle(color: Colors.white70, fontSize: 15),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),

          Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 15,
              left: 15,
              right: 15,
              top: 15
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF252525),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Add a comment...",
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _isPosting
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : CircleAvatar(
                      backgroundColor: Colors.blueAccent,
                      radius: 22,
                      child: IconButton(
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        onPressed: _postComment,
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildRankBadge(String rank, Color color) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
        ]
      ),
      child: Text(
        rank,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showDeleteConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Delete Account?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Are you sure? This action cannot be undone. All your data will be lost.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {

                await FirebaseAuth.instance.currentUser?.delete();

                if (context.mounted) {
                   Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const AuthSelectionScreen()),
                    (route) => false
                  );
                }
              } on FirebaseAuthException catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error: ${e.message}. Please log out and log in again to delete."),
                      backgroundColor: Colors.red,
                    )
                  );
                }
              } catch (e) {
                 if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text("Yes, Delete", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Log Out?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Are you sure you want to log out?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const AuthSelectionScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text("Log Out", style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, String currentName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();

    if (data != null && data['last_name_change'] != null) {
      final lastChange = (data['last_name_change'] as Timestamp).toDate();
      final difference = DateTime.now().difference(lastChange);
      if (difference.inDays < 7) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text("Wait a bit!", style: TextStyle(color: Colors.white)),
              content: Text(
                "You can only change your name once every 7 days.\nTime remaining: ${7 - difference.inDays} days.",
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("OK", style: TextStyle(color: Colors.blueAccent)),
                ),
              ],
            ),
          );
        }
        return;
      }
    }

    final controller = TextEditingController(text: currentName);
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Edit Nickname", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Enter new nickname",
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.length < 3) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Name too short!")));
                 return;
              }

              final query = await FirebaseFirestore.instance
                  .collection('users')
                  .where('nickname', isEqualTo: newName)
                  .get();

              if (query.docs.isNotEmpty) {
                 if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("This name is already taken!")));
                 }
                 return;
              }

              if (context.mounted) {
                 Navigator.pop(ctx);
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Updating profile...")));
              }

              WriteBatch batch = FirebaseFirestore.instance.batch();

              try {

                DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
                batch.update(userRef, {
                  'nickname': newName,
                  'last_name_change': FieldValue.serverTimestamp(),
                });

                QuerySnapshot userCommentsSnap = await userRef.collection('comments').get();
                for (var doc in userCommentsSnap.docs) {
                   String gameId = doc['gameId'];
                   String commentId = doc.id;

                   DocumentReference gameCommentRef = FirebaseFirestore.instance
                       .collection('oyunlar')
                       .doc(gameId)
                       .collection('comments')
                       .doc(commentId);
                   batch.update(gameCommentRef, {'nickname': newName});

                   batch.update(doc.reference, {'nickname': newName});
                }

                QuerySnapshot friendsSnap = await userRef.collection('friends').get();
                for (var doc in friendsSnap.docs) {
                  String friendId = doc.id;

                  DocumentReference meInFriendsList = FirebaseFirestore.instance
                      .collection('users')
                      .doc(friendId)
                      .collection('friends')
                      .doc(user.uid);

                  batch.update(meInFriendsList, {'nickname': newName});
                }

                await batch.commit();

                if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile & History Updated!")));
                }

              } catch (e) {
                debugPrint("Update Error: $e");
                 if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Partial consistency error: $e")));
                }
              }
            },
            child: const Text("Save", style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.black,

      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Profile not found.", style: TextStyle(color: Colors.white)));
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>;
          String nickname = userData['nickname'] ?? "Unknown";
          List<dynamic> likedGames = userData['liked_games'] ?? [];
          List<dynamic> dislikedGames = userData['disliked_games'] ?? [];

          List<dynamic> reversedGames = List.from(likedGames.reversed);

          List<dynamic> savedGames = userData['saved_games'] ?? [];
          List<dynamic> reversedSavedGames = List.from(savedGames.reversed);

          return Column(
            children: [

              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(color: Colors.blueAccent, blurRadius: 10, offset: Offset(0, 5), spreadRadius: -5)
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "My Profile",
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2.2,
                      ),
                    ),

                    Row(
                      children: [

                        IconButton(
                          icon: const Icon(Icons.delete_forever_rounded, color: Colors.white70, size: 28),
                          tooltip: "Delete Account",
                          onPressed: () => _showDeleteConfirmDialog(context),
                        ),

                        const SizedBox(width: 5),

                        IconButton(
                          icon: const Icon(Icons.logout, color: Colors.white, size: 28),
                          tooltip: "Log Out",
                          onPressed: () => _showLogoutConfirmDialog(context),
                        ),

                        const SizedBox(width: 5),

                        IconButton(
                          icon: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 28),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const FriendsHomeScreen()));
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Row(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.blueAccent,
                            child: Text(
                              nickname[0].toUpperCase(),
                              style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(nickname,
                                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                                    onPressed: () => _showEditNameDialog(context, nickname),
                                    tooltip: "Change Name",
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text("${userData['score'] ?? 0} Total Score", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 16)),
                              Text("${likedGames.length} Games Liked", style: const TextStyle(color: Colors.grey)),
                              if (dislikedGames.isNotEmpty)
                                GestureDetector(
                                  onTap: () async {
                                    WriteBatch batch = FirebaseFirestore.instance.batch();

                                    for (var gameId in dislikedGames) {
                                      var gameDislikeRef = FirebaseFirestore.instance
                                          .collection('oyunlar')
                                          .doc(gameId)
                                          .collection('dislikes')
                                          .doc(userId);
                                      batch.delete(gameDislikeRef);
                                    }

                                    var userRef = FirebaseFirestore.instance.collection('users').doc(userId);
                                    batch.update(userRef, {
                                      'disliked_games': []
                                    });

                                    await batch.commit();

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All disliked games restored!")));
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 5.0),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                         color: Colors.redAccent.withOpacity(0.2),
                                         borderRadius: BorderRadius.circular(5),
                                         border: Border.all(color: Colors.redAccent)
                                      ),
                                      child: Text("Restore ${dislikedGames.length} disliked games", style: const TextStyle(color: Colors.white, fontSize: 12)),
                                    ),
                                  ),
                                )
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const MyScoresScreen()));
                        },
                        icon: const Icon(Icons.leaderboard, color: Colors.amber),
                        label: const Text("View My Best Scores", style: TextStyle(color: Colors.white)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.amber),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),

                      const SizedBox(height: 10),

                      const SizedBox(height: 30),

                      if (reversedGames.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FavoritesFeedScreen(
                                  gameIds: List<String>.from(reversedGames),
                                  enableTutorial: true,
                                  title: "My Favorites",
                                  tutorialKey: "fav_feed_seen",
                                ),
                              ),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Colors.purpleAccent, Colors.deepPurple]),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(color: Colors.purpleAccent.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 5))
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Click To Play liked Games", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                      SizedBox(height: 5),
                                      Text("Swipe through only the games you love!", style: TextStyle(color: Colors.white70, fontSize: 10)),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 10),
                                Icon(Icons.play_circle_fill, color: Colors.white, size: 40),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 15),

                      if (reversedSavedGames.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FavoritesFeedScreen(
                                  gameIds: List<String>.from(reversedSavedGames),
                                  enableTutorial: true,
                                  title: "My Collection",
                                  tutorialKey: "saved_feed_seen",
                                ),
                              ),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFFFF512F), Color(0xFFDD2476)]),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(color: Colors.orangeAccent.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 5))
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Click To Play Saved Games", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                      SizedBox(height: 5),
                                      Text("Check out your bookmarked games!", style: TextStyle(color: Colors.white70, fontSize: 10)),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 10),
                                Icon(Icons.bookmark, color: Colors.white, size: 40),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 25),
                      const Text("Your Favorites History", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),

                      reversedGames.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(10)),
                              child: const Row(
                                children: [
                                  Icon(Icons.favorite_border, color: Colors.grey),
                                  SizedBox(width: 10),
                                  Text("No liked games yet. Go explore!", style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            )
                          : Expanded(
                              child: ListView.builder(
                                itemCount: reversedGames.length,
                                itemBuilder: (context, index) {
                                  String gameId = reversedGames[index];
                                  return FutureBuilder<DocumentSnapshot>(
                                    future: FirebaseFirestore.instance.collection('oyunlar').doc(gameId).get(),
                                    builder: (context, gameSnap) {
                                      if (!gameSnap.hasData) return const SizedBox.shrink();
                                      var gameData = gameSnap.data!.data() as Map<String, dynamic>?;
                                      if (gameData == null) return const SizedBox.shrink();

                                      return Card(
                                        color: Colors.grey[900],
                                        margin: const EdgeInsets.only(bottom: 10),
                                        child: ListTile(
                                          leading: const Icon(Icons.videogame_asset, color: Colors.purpleAccent, size: 40),
                                          title: Text(gameData['name'] ?? "Unknown Game", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          subtitle: const Text("Tap to play only this game", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                          trailing: const Icon(Icons.play_circle_fill, color: Colors.white),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => FavoritesFeedScreen(
                                                  gameIds: [gameId],
                                                  enableTutorial: false,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class FavoritesFeedScreen extends StatefulWidget {
  final List<String> gameIds;
  final bool enableTutorial;
  final String title;
  final String tutorialKey;

  const FavoritesFeedScreen({
    super.key,
    required this.gameIds,
    this.enableTutorial = false,
    this.title = "My Favorites",
    this.tutorialKey = "fav_feed_seen",
  });

  @override
  State<FavoritesFeedScreen> createState() => _FavoritesFeedScreenState();
}

class _FavoritesFeedScreenState extends State<FavoritesFeedScreen> with WidgetsBindingObserver {
  bool _showTutorial = false;

  List<DocumentSnapshot> _stableFeed = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkTutorial();

    ReklamYoneticisi().reklamiYukle();

    if (widget.gameIds.isNotEmpty) {
      _playMusicForGame(widget.gameIds[0]);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    MusicManager.instance.stopMusic();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        MusicManager.instance.pauseMusic();
        break;
      case AppLifecycleState.resumed:
        MusicManager.instance.resumeMusic();
        break;
    }
  }

  Future<void> _playMusicForGame(String gameId) async {
    try {
      var doc = await FirebaseFirestore.instance.collection('oyunlar').doc(gameId).get();
      if (doc.exists) {
        int? musicId = doc.data()?['music_id'];
        MusicManager.instance.playMusic(musicId);
      } else {
         MusicManager.instance.stopMusic();
      }
    } catch (e) {
      debugPrint("Music fetch error: $e");
    }
  }

  Future<void> _checkTutorial() async {
    if (!widget.enableTutorial) return;
    final prefs = await SharedPreferences.getInstance();
    bool seen = prefs.getBool(widget.tutorialKey) ?? false;
    if (!seen) {
      setState(() => _showTutorial = true);
    }
  }

  Future<void> _closeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(widget.tutorialKey, true);
    setState(() => _showTutorial = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,

        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: MusicManager.instance.isMutedNotifier,
            builder: (context, isMuted, child) {
              return IconButton(
                onPressed: () {
                  MusicManager.instance.toggleMute();
                },
                icon: Icon(
                  isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: Stack(
        children: [
          PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: widget.gameIds.length,

            onPageChanged: (int index) {

               if (index < widget.gameIds.length) {
                 _playMusicForGame(widget.gameIds[index]);
               }

               final reklamYoneticisi = ReklamYoneticisi();
               if (reklamYoneticisi.shouldShowAd()) {
                 print("🎯 FAVORİLERDE REKLAM TETİKLENDİ!");
                 reklamYoneticisi.reklamiGoster(onClosed: () {
                   setState(() {});
                 });
               }
            },

            itemBuilder: (context, index) {
              String gameId = widget.gameIds[index];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('oyunlar').doc(gameId).get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  var data = snapshot.data!.data() as Map<String, dynamic>?;

                  if (data == null) {
                    return const Center(child: Text("Oyun bulunamadı", style: TextStyle(color: Colors.white)));
                  }

                  String url = data['url'];
                  String gameName = data['name'] ?? 'Game';
                  String gameType = data['type'] ?? 'type1';

                  return OyunPenceresi(url: url, docId: gameId, gameName: gameName, gameType: gameType);
                },
              );
            },
          ),

          if (_showTutorial)
            GestureDetector(
              onTap: _closeTutorial,
              child: Container(
                color: Colors.black.withOpacity(0.85),
                width: double.infinity,
                height: double.infinity,
                child: SafeArea(
                  child: Column(
                    children: [
                      const Spacer(),
                      const Icon(Icons.favorite, color: Colors.redAccent, size: 80),
                      const SizedBox(height: 20),
                      const Text(
                        "Your Collection is Here!",
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "All your Collection games are stored here.\nSwipe up to play.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: _closeTutorial,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: const Text("Let's Play!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  }

class LeaderboardSheet extends StatefulWidget {
  final String gameId;
  const LeaderboardSheet({super.key, required this.gameId});

  @override
  State<LeaderboardSheet> createState() => _LeaderboardSheetState();
}

class _LeaderboardSheetState extends State<LeaderboardSheet> {
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  Future<int> _getUserRank(int myScore) async {

    AggregateQuerySnapshot countQuery = await FirebaseFirestore.instance
        .collection('games')
        .doc(widget.gameId)
        .collection('leaderboard')
        .where('score', isGreaterThan: myScore)
        .count()
        .get();

    return (countQuery.count ?? 0) + 1;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.60,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 50,
            spreadRadius: 5,
          )
        ],
      ),
      child: Column(
        children: [

          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                 Icon(Icons.emoji_events, color: Colors.amber, size: 28),
                 SizedBox(width: 10),
                 Text("Leaderboard", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          const Divider(color: Colors.white10, height: 1),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('games')
                  .doc(widget.gameId)
                  .collection('leaderboard')
                  .orderBy('score', descending: true)
                  .limit(3)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snapshot.data?.docs ?? [];

                return Column(
                  children: [

                    if (docs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text("No scores yet. Be the first!", style: TextStyle(color: Colors.grey)),
                      )
                    else
                      ListView.builder(
                        padding: const EdgeInsets.all(20),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          var data = docs[index].data() as Map<String, dynamic>;
                          int rank = index + 1;
                          String nickname = data['nickname'] ?? "Unknown";
                          int score = data['score'] ?? 0;

                          Color color;
                          if (rank == 1) color = const Color(0xFFFFD700);
                          else if (rank == 2) color = const Color(0xFFC0C0C0);
                          else color = const Color(0xFFCD7F32);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: color.withOpacity(0.5)),
                            ),
                            child: Row(
                              children: [

                                Container(
                                  width: 30, height: 30,
                                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                  alignment: Alignment.center,
                                  child: Text("$rank", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 15),

                                Expanded(
                                  child: Text(nickname, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                ),

                                Text("$score", style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        },
                      ),

                    const Spacer(),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      color: Colors.black.withOpacity(0.3),
                      child: StreamBuilder<DocumentSnapshot>(

                        stream: FirebaseFirestore.instance
                            .collection('games')
                            .doc(widget.gameId)
                            .collection('leaderboard')
                            .doc(currentUserId)
                            .snapshots(),
                        builder: (context, myScoreSnapshot) {
                          if (!myScoreSnapshot.hasData || !myScoreSnapshot.data!.exists) {
                             return const Text("Play to get a rank!", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey));
                          }

                          var myData = myScoreSnapshot.data!.data() as Map<String, dynamic>;
                          int myScore = myData['score'] ?? 0;

                          return FutureBuilder<int>(
                            future: _getUserRank(myScore),
                            builder: (context, rankSnapshot) {
                              if (rankSnapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
                              }

                              int myRank = rankSnapshot.data ?? 0;

                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("YOUR RANK", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1)),
                                      const SizedBox(height: 5),
                                      Text("#$myRank", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text("SCORE", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1)),
                                      const SizedBox(height: 5),
                                      Text("$myScore", style: const TextStyle(color: Colors.blueAccent, fontSize: 24, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

