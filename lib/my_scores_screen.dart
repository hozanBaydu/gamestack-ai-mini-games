import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyScoresScreen extends StatelessWidget {
  const MyScoresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("My Best Scores"),
        backgroundColor: Colors.transparent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('game_scores')
            .orderBy('score', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No scores recorded yet.", style: TextStyle(color: Colors.white)));
          }

          var docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              var score = data['score'];
              var gameName = data['gameName'] ?? 'Unknown Game';
              var type = data['type'] ?? 'type1';

              if (type == 'type2') {
                return const SizedBox.shrink();
              }

              return Card(
                color: Colors.grey[900],
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.blueAccent.withOpacity(0.3))),
                child: ListTile(
                  leading: const CircleAvatar(
                      backgroundColor: Colors.amber,
                      child: Icon(Icons.star, color: Colors.black)
                  ),
                  title: Text(gameName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  trailing: Text(
                    "$score",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace'
                    )
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

