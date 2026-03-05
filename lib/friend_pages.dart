
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendsHomeScreen extends StatelessWidget {
  const FriendsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text("Social Hub", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add, color: Colors.blueAccent),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddFriendScreen()),
                );
              },
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.blueAccent,
            tabs: [
              Tab(text: "Friends"),
              Tab(text: "Requests"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            FriendsListTab(),
            FriendRequestsTab(),
          ],
        ),
      ),
    );
  }
}

class FriendsListTab extends StatelessWidget {
  const FriendsListTab({super.key});

  Future<void> _removeFriend(BuildContext context, String friendUid, String friendNickname) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Remove Friend", style: TextStyle(color: Colors.white)),
        content: Text("Are you sure you want to remove $friendNickname from your friends?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Remove", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final firestore = FirebaseFirestore.instance;

      await firestore.collection('users').doc(myUid).collection('friends').doc(friendUid).delete();

      await firestore.collection('users').doc(friendUid).collection('friends').doc(myUid).delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$friendNickname removed.")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error removing friend: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return const Center(child: Text("Please log in", style: TextStyle(color: Colors.white)));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .collection('friends')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people_outline, size: 60, color: Colors.grey),
                const SizedBox(height: 10),
                const Text("No friends yet.", style: TextStyle(color: Colors.grey)),
                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AddFriendScreen()));
                  },
                  child: const Text("Add a Friend", style: TextStyle(color: Colors.blueAccent)),
                ),
              ],
            ),
          );
        }

        var friends = snapshot.data!.docs;

        return ListView.builder(
          itemCount: friends.length,
          itemBuilder: (context, index) {
            var friendData = friends[index].data() as Map<String, dynamic>;
            var friendUid = friends[index].id;
            var nickname = friendData['nickname'] ?? 'Unknown';

            return Card(
              color: Colors.grey[900],
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: Text(nickname[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                ),
                title: Text(nickname, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text("Tap to compare scores", style: TextStyle(color: Colors.grey)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.bar_chart, color: Colors.greenAccent),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ScoreComparisonScreen(
                              friendUid: friendUid,
                              friendNickname: nickname,
                            ),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.person_remove, color: Colors.redAccent),
                      onPressed: () => _removeFriend(context, friendUid, nickname),
                    ),
                  ],
                ),
                onTap: () {
                   Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ScoreComparisonScreen(
                        friendUid: friendUid,
                        friendNickname: nickname,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class FriendRequestsTab extends StatelessWidget {
  const FriendRequestsTab({super.key});

  Future<void> _respondToRequest(String requestId, String fromUid, String fromNickname, bool accept) async {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final firestore = FirebaseFirestore.instance;

    try {
      if (accept) {

        await firestore.collection('friend_requests').doc(requestId).update({'status': 'accepted'});

        await firestore.collection('users').doc(myUid).collection('friends').doc(fromUid).set({
          'nickname': fromNickname,
          'since': FieldValue.serverTimestamp(),
        });

        final myDoc = await firestore.collection('users').doc(myUid).get();
        final myNickname = myDoc.data()?['nickname'] ?? 'Player';

        await firestore.collection('users').doc(fromUid).collection('friends').doc(myUid).set({
          'nickname': myNickname,
          'since': FieldValue.serverTimestamp(),
        });

      } else {

        await firestore.collection('friend_requests').doc(requestId).update({'status': 'rejected'});
      }
    } catch (e) {
      debugPrint("Error responding to request: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('friend_requests')
          .where('to_uid', isEqualTo: myUid)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No pending requests.", style: TextStyle(color: Colors.grey)));
        }

        var requests = snapshot.data!.docs;

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            var req = requests[index];
            var data = req.data() as Map<String, dynamic>;
            var fromNickname = data['from_nickname'] ?? 'Unknown';
            var fromUid = data['from_uid'];

            return Card(
              color: Colors.grey[900],
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: ListTile(
                leading: const Icon(Icons.person_add_alt_1, color: Colors.orangeAccent),
                title: Text(fromNickname, style: const TextStyle(color: Colors.white)),
                subtitle: const Text("Sent you a friend request", style: TextStyle(color: Colors.grey)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () => _respondToRequest(req.id, fromUid, fromNickname, true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => _respondToRequest(req.id, fromUid, fromNickname, false),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final _searchController = TextEditingController();
  List<DocumentSnapshot> _searchResults = [];
  bool _isLoading = false;
  String? _feedbackMessage;

  Future<void> _searchUser() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _searchResults = [];
      _feedbackMessage = null;
    });

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('nickname', isEqualTo: query)
          .get();

      setState(() {
        _searchResults = snap.docs;
        if (_searchResults.isEmpty) {
          _feedbackMessage = "User not found.";
        }
      });
    } catch (e) {
      setState(() => _feedbackMessage = "Error searching.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendRequest(String toUid, String toNickname) async {
    final myUser = FirebaseAuth.instance.currentUser;
    if (myUser == null) return;

    if (toUid == myUser.uid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You cannot add yourself!")));
      return;
    }

    try {

      final myDoc = await FirebaseFirestore.instance.collection('users').doc(myUser.uid).get();
      final myNickname = myDoc.data()?['nickname'] ?? 'Player';

      await FirebaseFirestore.instance.collection('friend_requests').add({
        'from_uid': myUser.uid,
        'from_nickname': myNickname,
        'to_uid': toUid,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request Sent!")));
       Navigator.pop(context);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("Add Friend"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[900],
                hintText: "Enter username...",
                hintStyle: const TextStyle(color: Colors.grey),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Colors.blueAccent),
                  onPressed: _searchUser,
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading) const CircularProgressIndicator(),
            if (_feedbackMessage != null) Text(_feedbackMessage!, style: const TextStyle(color: Colors.white)),

            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  var data = _searchResults[index].data() as Map<String, dynamic>;
                  var nickname = data['nickname'];
                  var uid = _searchResults[index].id;

                  return Card(
                    color: Colors.grey[850],
                    child: ListTile(
                      title: Text(nickname, style: const TextStyle(color: Colors.white)),
                      trailing: ElevatedButton(
                        onPressed: () => _sendRequest(uid, nickname),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                        child: const Text("Add", style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScoreComparisonScreen extends StatefulWidget {
  final String friendUid;
  final String friendNickname;

  const ScoreComparisonScreen({
    super.key,
    required this.friendUid,
    required this.friendNickname
  });

  @override
  State<ScoreComparisonScreen> createState() => _ScoreComparisonScreenState();
}

class _ScoreComparisonScreenState extends State<ScoreComparisonScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _commonGames = [];
  int _myWins = 0;
  int _friendWins = 0;

  @override
  void initState() {
    super.initState();
    _fetchAndCompareScores();
  }

  Future<void> _fetchAndCompareScores() async {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final firestore = FirebaseFirestore.instance;

    try {

      final myScoresSnap = await firestore.collection('users').doc(myUid).collection('game_scores').get();
      Map<String, int> myScores = {};
      Map<String, String> gameNames = {};

      for (var doc in myScoresSnap.docs) {
        var data = doc.data();

        if ((data['type'] ?? 'type1') != 'type2') {
           myScores[doc.id] = data['score'] ?? 0;
           gameNames[doc.id] = data['gameName'] ?? 'Unknown Game';
        }
      }

      final friendScoresSnap = await firestore.collection('users').doc(widget.friendUid).collection('game_scores').get();
      Map<String, int> friendScores = {};
      for (var doc in friendScoresSnap.docs) {

         if ((doc.data()['type'] ?? 'type1') != 'type2') {
           friendScores[doc.id] = doc.data()['score'] ?? 0;
         }
      }

      List<Map<String, dynamic>> tempCommon = [];
      int tempMyWins = 0;
      int tempFriendWins = 0;

      for (var gameId in myScores.keys) {
        if (friendScores.containsKey(gameId)) {
          int myScore = myScores[gameId]!;
          int otherScore = friendScores[gameId]!;

          if (myScore > otherScore) tempMyWins++;
          if (otherScore > myScore) tempFriendWins++;

          tempCommon.add({
            'gameId': gameId,
            'gameName': gameNames[gameId],
            'myScore': myScore,
            'otherScore': otherScore,
          });
        }
      }

      setState(() {
        _commonGames = tempCommon;
        _myWins = tempMyWins;
        _friendWins = tempFriendWins;
        _isLoading = false;
      });

    } catch (e) {
      debugPrint("Comparison Error: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text("Vs ${widget.friendNickname}"),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [

              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.purpleAccent]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.5), blurRadius: 20)],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text("YOU", style: TextStyle(color: Colors.white70, fontSize: 16)),
                        Text("$_myWins", style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Text("-", style: TextStyle(color: Colors.white, fontSize: 40)),
                    Column(
                      children: [
                        Text(widget.friendNickname.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 16)),
                        Text("$_friendWins", style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Common Games", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),

              Expanded(
                child: _commonGames.isEmpty
                  ? Center(child: Text("No common games played yet!", style: TextStyle(color: Colors.grey[600])))
                  : ListView.builder(
                      itemCount: _commonGames.length,
                      itemBuilder: (context, index) {
                        var game = _commonGames[index];
                        bool iWon = game['myScore'] > game['otherScore'];
                        bool draw = game['myScore'] == game['otherScore'];

                        return Card(
                          color: Colors.grey[900],
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              color: iWon ? Colors.green : (draw ? Colors.grey : Colors.red),
                              width: 2
                            ),
                            borderRadius: BorderRadius.circular(12)
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                const Icon(Icons.videogame_asset, color: Colors.white),
                                const SizedBox(width: 10),
                                Expanded(

                                  child: Text(
                                    game['gameName'] ?? "Game",
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  "${game['myScore']}",
                                  style: TextStyle(
                                    color: iWon ? Colors.greenAccent : Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold
                                  )
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Text("vs", style: TextStyle(color: Colors.grey)),
                                ),
                                Text(
                                  "${game['otherScore']}",
                                  style: TextStyle(
                                    color: !iWon && !draw ? Colors.redAccent : Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold
                                  )
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
    );
  }
}

