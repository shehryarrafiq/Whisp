import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendListScreen extends StatelessWidget {
  const FriendListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 1, 77, 164),
        title: const Text(
          'Your Buddies on Whisp',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .collection('contacts')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading friends"));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No friends found"));
          }

          // List of friends fetched from Firestore
          final friends = snapshot.data!.docs;

          return ListView.builder(
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];
              final fullName = friend['fullName'] ?? 'No Name';
              final userName = friend['username'] ?? 'No Username';
              final profilePicture = friend['profilePicture'];

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage:
                      profilePicture != null && profilePicture.isNotEmpty
                          ? NetworkImage(profilePicture)
                          : const AssetImage('assets/profile_placeholder.png')
                              as ImageProvider,
                ),
                title: Text(fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('@$userName'),
                trailing: IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    _showRemoveFriendDialog(
                        context, friend.id, friend['invitationId']);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Function to show a dialog for removing a friend
  void _showRemoveFriendDialog(
      BuildContext context, String friendId, String invitationId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove Friend'),
          content: const Text('Are you sure you want to remove this friend?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await _removeFriend(friendId, invitationId);
                Navigator.pop(context);
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  // Function to remove a friend using batch delete
  Future<void> _removeFriend(String friendId, String invitationId) async {
    User? user = FirebaseAuth.instance.currentUser;
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    if (user != null) {
      final currentUserContactsRef = firestore
          .collection('users')
          .doc(user.uid)
          .collection('contacts')
          .doc(friendId);

      final friendUserContactsRef = firestore
          .collection('users')
          .doc(friendId)
          .collection('contacts')
          .doc(user.uid);

      final invitationRef =
          firestore.collection('invitations').doc(invitationId);

      // Generate the chatId based on both user IDs
      List<String> sortedIds = [user.uid, friendId]
        ..sort(); // Sort the user IDs
      String chatId = sortedIds.join("_"); // Join the sorted IDs to form chatId

      final chatRef = firestore.collection('chats').doc(chatId);

      try {
        // Start a batch
        WriteBatch batch = firestore.batch();

        // Add the deletions to the batch
        batch.delete(currentUserContactsRef);
        batch.delete(friendUserContactsRef);
        batch.delete(invitationRef);
        batch.delete(chatRef); // Delete the chat document

        // Commit the batch
        await batch.commit();
        print("Unfriend and chat deletion operation successful.");
      } catch (e) {
        print("Error unfriending user and deleting chat: $e");
      }
    }
  }
}
